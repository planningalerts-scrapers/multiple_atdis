#!/usr/bin/env ruby
Bundler.require

AUTHORITIES = {
  bega_valley: {
    url: "http://datracker.begavalley.nsw.gov.au/ATDIS/1.0/"
  },
  ballina: {
    url: "http://da.ballina.nsw.gov.au/atdis/1.0"
  },
  bathurst: {
    url: "http://masterview.bathurst.nsw.gov.au/atdis/1.0/"
  },
  berrigan: {
    url: "http://datracking.berriganshire.nsw.gov.au/Horizon/@@horizondap@@/atdis/1.0/"
  },
  dubbo: {
    url: "https://planning.dubbo.nsw.gov.au/atdis/1.0/"
  },
  kiama: {
    url: "https://da.kiama.nsw.gov.au/atdis/1.0"
  },
  upper_hunter: {
    url: "http://onlineservices.upperhunter.nsw.gov.au/atdis/1.0/"
  },
  armidale: {
    url: "https://epathway.newengland.nsw.gov.au/ePathway/Production/WebServiceGateway/atdis/1.0"
  },
  ashfield: {
    url: "http://mycouncil.solorient.com.au/Horizon/@@horizondap_ashfield@@/atdis/1.0/"
  },
  leeton: {
    url: "http://203.58.97.252/Horizon/@@horizondap@@/atdis/1.0/"
  },
  muswellbrook: {
    url: "https://datracker.muswellbrook.nsw.gov.au/atdis/1.0"
  },
  walgett: {
    url: "http://myhorizon.walgett.nsw.gov.au/Horizon/@@horizondap@@/atdis/1.0/"
  },
  newcastle: {
    url: "https://property.ncc.nsw.gov.au/T1PRPROD/WebAppServices/ATDIS/atdis/1.0"
  }
}

exceptions = []
AUTHORITIES.each do |authority_label, params|
  puts "\nCollecting ATDIS feed data for #{authority_label}..."

  begin
    # All the authorities are in NSW (for ATDIS) so they all have
    # the Sydney timezone
    ATDISPlanningAlertsFeed.fetch(params[:url], "Sydney") do |record|
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
