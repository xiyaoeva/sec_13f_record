namespace :sec_13f_record do
  desc "Initialize by importing and processing two specified quarters: rake sec_13f_record:init_two_quarters[2025,4,2026,1]"
  task :init_two_quarters, [:year1, :quarter1, :year2, :quarter2] => :environment do |_t, args|
    required = %i[year1 quarter1 year2 quarter2]
    missing = required.select { |k| args[k].blank? }
    if missing.any?
      abort("Missing args: #{missing.join(', ')}. Example: rake sec_13f_record:init_two_quarters[2025,4,2026,1]")
    end

    quarters = [
      [args[:year1].to_i, args[:quarter1].to_i],
      [args[:year2].to_i, args[:quarter2].to_i]
    ]

    quarters.each do |year, quarter|
      unless (1..4).include?(quarter)
        abort("Invalid quarter #{quarter}. Must be 1..4")
      end

      puts "#{Time.zone.now}: importing filings for #{year} Q#{quarter}"
      ThirteenF.import_filings!(filing_year: year, filing_quarter: quarter)

      puts "#{Time.zone.now}: processing unprocessed filings for #{year} Q#{quarter}"
      ThirteenF.process_unprocessed_filings!(
        filing_year: year,
        filing_quarter: quarter,
        refresh_views: false
      )
    end

    puts "#{Time.zone.now}: refreshing materialized views"
    ThirteenFFiler.refresh!
    CompanyCusipLookup.refresh!
    CusipQuarterlyFilingsCount.refresh!

    puts "Done: initialized two quarters #{quarters.map { |y, q| "#{y}Q#{q}" }.join(', ')}"
  end

  desc "Export keyword comparison CSVs: rake sec_13f_record:export_keyword[intc,100]"
  task :export_keyword, [:keyword, :limit] => :environment do |_t, args|
    keyword = args[:keyword].to_s.strip
    abort("keyword is required. Example: rake sec_13f_record:export_keyword[intc]") if keyword.blank?

    limit = args[:limit]&.to_i

    result = KeywordComparisonExporter.new(keyword: keyword, limit: limit).run

    puts "Keyword: #{result.keyword}"
    puts "Managers exported: #{result.managers_exported}"
    puts "Matched rows exported: #{result.rows_exported}"
    puts "Output directory: #{result.output_dir}"
  end
end
