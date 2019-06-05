#!/usr/bin/env ruby
Bundler.require

AUTHORITIES = {
  bega_valley: "http://datracker.begavalley.nsw.gov.au/ATDIS/1.0/",
  ballina: "http://da.ballina.nsw.gov.au/atdis/1.0",
  bathurst: "http://masterview.bathurst.nsw.gov.au/atdis/1.0/",
  berrigan: "http://datracking.berriganshire.nsw.gov.au/Horizon/@@horizondap@@/atdis/1.0/",
  dubbo: "https://planning.dubbo.nsw.gov.au/atdis/1.0/",
  kiama: "https://da.kiama.nsw.gov.au/atdis/1.0",
  upper_hunter: "http://onlineservices.upperhunter.nsw.gov.au/atdis/1.0/",
  armidale: "https://epathway.newengland.nsw.gov.au/ePathway/Production/WebServiceGateway/atdis/1.0",

  # Commenting out ATDIS feeds that used to work but do not appear
  # to be working anymore
  # ashfield: "http://mycouncil2.solorient.com.au/Horizon/@@horizondap_ashfield@@/atdis/1.0/",
  # cootamundra: "http://myhorizon.cootamundra.nsw.gov.au/Horizon/@@horizondap@@/atdis/1.0/",
  # leeton: "http://203.58.97.252/Horizon/@@horizondap@@/atdis/1.0/",
  # muswellbrook: "http://datracker.muswellbrook.nsw.gov.au/atdis/1.0",
  # walgett: "http://myhorizon.walgett.nsw.gov.au/Horizon/@@horizondap@@/atdis/1.0/"
}

exceptions = []
AUTHORITIES.each do |authority_label, url|
  puts "\nCollecting ATDIS feed data for #{authority_label}..."

  begin
    # All the authorities are in NSW (for ATDIS) so they all have
    # the Sydney timezone
    ATDISPlanningAlertsFeed.fetch(url, "Sydney") do |record|
      record[:authority_label] = authority_label.to_s
      puts "Storing #{record[:council_reference]} - #{record[:address]}"
      ScraperWikiMorph.save_sqlite([:authority_label, :council_reference], record)
    end
  rescue StandardError => e
    STDERR.puts "#{authority_label}: ERROR: #{e}"
    STDERR.puts e.backtrace
    exceptions << e
  end
end

unless exceptions.empty?
  raise "There were earlier errors. See output for details"
end
