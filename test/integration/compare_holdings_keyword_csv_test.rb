require "test_helper"
require "csv"

class CompareHoldingsKeywordCsvTest < ActionDispatch::IntegrationTest
  def setup
    @current_filing = create_filing(
      external_id: "0000000000-26-000001",
      report_date: Date.new(2026, 3, 31),
      filing_year: 2026,
      filing_quarter: 1
    )
    @previous_filing = create_filing(
      external_id: "0000000000-25-000001",
      report_date: Date.new(2025, 12, 31),
      filing_year: 2025,
      filing_quarter: 4
    )
  end

  test "downloads csv filtered by keyword across symbol and holdings fields" do
    AggregateHolding.create!(
      thirteen_f_id: @current_filing.id,
      cusip: "111111111",
      issuer_name: "Some Company",
      class_title: "COM",
      shares_or_principal_amount_type: "sh",
      option_type: nil,
      value: 1000,
      shares_or_principal_amount: 100
    )
    AggregateHolding.create!(
      thirteen_f_id: @previous_filing.id,
      cusip: "222222222",
      issuer_name: "Legacy Position",
      class_title: "COM",
      shares_or_principal_amount_type: "sh",
      option_type: nil,
      value: 2000,
      shares_or_principal_amount: 200
    )

    CusipSymbolMapping.create!(cusip: "111111111", symbol: "INTC", name: "Intel", exchange: "NASDAQ")

    get thirteen_f_comparison_keyword_csv_path(
      external_id: @current_filing.external_id,
      other_external_id: @previous_filing.external_id
    ), params: {keyword: "intc"}

    assert_response :success
    assert_match("text/csv", response.headers["Content-Type"])

    rows = CSV.parse(response.body, headers: true)
    assert_equal(1, rows.length)
    assert_equal("INTC", rows[0]["Sym"])
    assert_equal("Some Company", rows[0]["Issuer Name"])
    assert_equal("111111111", rows[0]["CUSIP"])
  end

  test "returns bad request for blank keyword" do
    get thirteen_f_comparison_keyword_csv_path(
      external_id: @current_filing.external_id,
      other_external_id: @previous_filing.external_id
    ), params: {keyword: " "}

    assert_response :bad_request
  end

  test "returns bad request when filings have different cik" do
    other_cik_filing = create_filing(
      external_id: "0000000000-25-000999",
      cik: "0000009999",
      report_date: Date.new(2025, 12, 31),
      filing_year: 2025,
      filing_quarter: 4
    )

    get thirteen_f_comparison_keyword_csv_path(
      external_id: @current_filing.external_id,
      other_external_id: other_cik_filing.external_id
    ), params: {keyword: "intc"}

    assert_response :bad_request
  end

  private

  def create_filing(external_id:, report_date:, filing_year:, filing_quarter:, cik: "0000001234")
    filing = ThirteenF.new(
      external_id: external_id,
      cik: cik,
      name: "Test Manager LP",
      form_type: "13F-HR",
      directory_url: "https://example.com/filings/#{external_id}",
      date_filed: report_date + 45.days,
      report_date: report_date,
      report_year: report_date.year,
      report_quarter: ((report_date.month - 1) / 3 + 1),
      filing_year: filing_year,
      filing_quarter: filing_quarter,
      xml_data_fetched_at: Time.zone.now
    )
    filing.save!(validate: false)
    filing
  end
end
