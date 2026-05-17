# frozen_string_literal: true
require "csv"

class KeywordComparisonExporter
  Result = Struct.new(:keyword, :managers_exported, :rows_exported, :output_dir, keyword_init: true)

  def initialize(keyword:, limit: nil, output_dir: Rails.root.join("exports/keyword_comparisons"), not_have_label: "not have data")
    @keyword = keyword.to_s.strip
    @limit = limit
    @output_dir = output_dir
    @not_have_label = not_have_label
  end

  def run
    raise ArgumentError, "keyword is required" if @keyword.blank?

    scoped = filings_scope
    latest = scoped.select("DISTINCT ON (cik) thirteen_fs.*").order("cik, report_date DESC, date_filed DESC, id DESC")
    latest = latest.limit(@limit) if @limit&.positive?

    managers_exported = 0
    rows_exported = 0

    latest.each do |current_filing|
      previous_filing, previous_year, previous_quarter = find_natural_previous_filing(scoped, current_filing)
      rows = build_rows(current_filing, previous_filing)
      next if rows.empty?

      write_csv(current_filing, previous_filing, previous_year, previous_quarter, rows)
      managers_exported += 1
      rows_exported += rows.size
    end

    Result.new(
      keyword: @keyword,
      managers_exported: managers_exported,
      rows_exported: rows_exported,
      output_dir: @output_dir
    )
  end

  private

  def filings_scope
    ThirteenF.processed.exclude_restated.where.not(report_date: nil)
  end

  def find_natural_previous_filing(scoped, current_filing)
    current_year = current_filing.report_year
    current_quarter = current_filing.report_quarter
    previous_quarter = current_quarter == 1 ? 4 : current_quarter - 1
    previous_year = current_quarter == 1 ? current_year - 1 : current_year

    previous_filing = scoped
      .where(cik: current_filing.cik, report_year: previous_year, report_quarter: previous_quarter)
      .order(report_date: :desc, date_filed: :desc, id: :desc)
      .first

    [previous_filing, previous_year, previous_quarter]
  end

  def build_rows(current_filing, previous_filing)
    previous_filing_present = previous_filing.present?
    previous_query = previous_filing_present ? "WHERE thirteen_f_id = :previous_id" : "WHERE 1=0"

    query = <<~SQL
      WITH current_filing AS (
        SELECT *
        FROM aggregate_holdings
        WHERE thirteen_f_id = :current_id
      ),
      previous_filing AS (
        SELECT *
        FROM aggregate_holdings
        #{previous_query}
      )
      SELECT
        coalesce(c.issuer_name, p.issuer_name) AS issuer_name,
        coalesce(c.class_title, p.class_title) AS class_title,
        coalesce(c.cusip, p.cusip) AS cusip,
        coalesce(c.option_type, p.option_type) AS option_type,
        c.value AS current_value,
        p.value AS previous_value,
        c.shares_or_principal_amount AS current_amount,
        p.shares_or_principal_amount AS previous_amount
      FROM current_filing c
      FULL OUTER JOIN previous_filing p
        ON c.cusip = p.cusip
        AND coalesce(c.option_type, '') = coalesce(p.option_type, '')
    SQL

    params = { current_id: current_filing.id }
    params[:previous_id] = previous_filing.id if previous_filing_present

    raw_rows = AggregateHolding.find_by_sql([query, params])
    symbol_by_cusip = CusipSymbolMapping.where(cusip: raw_rows.map(&:cusip).uniq).pluck(:cusip, :symbol).to_h
    normalized_keyword = @keyword.to_s.strip.upcase

    raw_rows.filter_map do |r|
      cusip = r.cusip.to_s.strip.upcase
      next unless cusip == normalized_keyword
      symbol = symbol_by_cusip[r.cusip]

      current_amount = r.current_amount.to_i
      previous_amount = r.previous_amount.to_i
      current_value = r.current_value.to_i
      previous_value = r.previous_value.to_i

      [
        symbol,
        r.issuer_name,
        r.class_title.to_s.upcase,
        r.cusip,
        r.option_type,
        metric_value(previous_amount, previous_filing_present),
        metric_value(current_amount, true),
        diff_value(current_amount, previous_amount, true, previous_filing_present),
        previous_filing_present ? pct_value(current_amount, previous_amount) : @not_have_label,
        metric_value(previous_value, previous_filing_present),
        metric_value(current_value, true),
        diff_value(current_value, previous_value, true, previous_filing_present),
        previous_filing_present ? pct_value(current_value, previous_value) : @not_have_label
      ]
    end
  end

  def write_csv(current_filing, previous_filing, previous_year, previous_quarter, rows)
    @output_dir.mkpath

    previous_label = previous_filing&.qq_yyyy || "Q#{previous_quarter} #{previous_year}"
    current_label = current_filing.qq_yyyy
    safe_manager_name = current_filing.name.to_s.gsub(/[\\\/:*?"<>|]/, " ").squish
    filename = "#{safe_manager_name} #{previous_label} vs. #{current_label} 13F Holdings Comparison.csv"

    CSV.open(@output_dir.join(filename), "wb", write_headers: true, headers: headers_for(previous_label, current_label)) do |csv|
      rows.sort_by { |r| [r[0].to_s, r[1].to_s] }.each { |row| csv << row }
    end
  end

  def headers_for(previous_label, current_label)
    [
      "Sym",
      "Issuer Name",
      "Cl",
      "CUSIP",
      "Option Type",
      previous_label,
      current_label,
      "Diff",
      "Chg %",
      previous_label,
      current_label,
      "Diff",
      "Chg %"
    ]
  end

  def metric_value(value, filing_present)
    return @not_have_label unless filing_present
    format_int(value)
  end

  def diff_value(current, previous, current_filing_present, previous_filing_present)
    return @not_have_label unless current_filing_present && previous_filing_present
    format_int(current.to_i - previous.to_i)
  end

  def pct_value(current, previous)
    return "0%" if previous.to_f.zero?
    "#{(100.0 * (current.to_f / previous.to_f - 1.0)).round}%"
  end

  def format_int(value)
    ActiveSupport::NumberHelper.number_to_delimited(value.to_i)
  end
end
