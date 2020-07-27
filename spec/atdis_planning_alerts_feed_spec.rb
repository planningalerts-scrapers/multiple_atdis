# frozen_string_literal: true

# TODO: Shift to spec helper

$LOAD_PATH << "#{File.dirname(__FILE__)}/.."
require "atdisplanningalertsfeed"

Bundler.require :development, :test

require "vcr"

VCR.configure do |c|
  c.cassette_library_dir = "spec/cassettes"
  c.allow_http_connections_when_no_cassette = true
  c.hook_into :webmock
  c.default_cassette_options = { record: :new_episodes }
  c.configure_rspec_metadata!
end

describe ATDISPlanningAlertsFeed, :vcr do
  let(:options) do
    {
      lodgement_date_start: Date.parse("2016-02-21"),
      lodgement_date_end: Date.parse("2016-03-22"),
      # Make the tests run quietly
      logger: Logger.new("/dev/null")
    }
  end

  context "valid feed" do
    let(:records) do
      ATDISPlanningAlertsFeed.return(
        "http://mycouncil2.solorient.com.au/Horizon/@@horizondap_ashfield@@/atdis/1.0/",
        "UTC",
        options
      )
    end

    it "should not error on empty feed" do
      expect(records.length).to eq 0
    end
  end

  context "feed with datetime in UTC" do
    let(:records) do
      ATDISPlanningAlertsFeed.return(
        "https://jamezpolley.github.io/atdis_utcdatetime_test/atdis/1.0",
        # The timezone for the council
        "Sydney",
        # In this case the options will be ignored by the receiving server
        options
      )
    end

    it "should convert the date received to the local timezone" do
      expect(records[0][:date_received].to_s).to eq "2018-08-22"
    end
  end

  context "dodgy pagination" do
    let(:records) do
      ATDISPlanningAlertsFeed.return(
        "https://myhorizon.maitland.nsw.gov.au/Horizon/@@horizondap@@/atdis/1.0/",
        "UTC",
        options
      )
    end

    it "should not error" do
      expect(records.length).to eq 120
    end
  end

  context "really dodgy pagination" do
    let(:records) do
      ATDISPlanningAlertsFeed.return(
        "https://da.kiama.nsw.gov.au/atdis/1.0/",
        "UTC",
        options
      )
    end

    it "should not error" do
      expect(records.length).to eq 43
    end
  end

  context "with a flakey service cootamundra" do
    let(:records) do
      ATDISPlanningAlertsFeed.return(
        "http://myhorizon.cootamundra.nsw.gov.au/Horizon/@@horizondap@@/atdis/1.0/",
        "UTC",
        options.merge(flakey: true)
      )
    end

    # TODO: This spec should always force a
    # RestClient::InternalServerError: 500 Internal Server Error
    it "should not error" do
      # TODO: This doesn't work as expected (stackleveltoodeep), but the VCR cassette should work
      # allow_any_instance_of(ATDIS::Feed).to
      # receive(:applications).and_raise(
      #   RestClient::InternalServerError.new("500 Internal Server Error"))
      # TODO: Expectation that a HTTP 500 on the first page recovers gracefully
      expect(records.length).to eq 0
    end
  end

  context "with a flakey service yass" do
    let(:records) do
      # Yass isn't actually flakey, but Cootamundra is *too* flakey
      # This scenario replicates one page of many having an unhandled exception
      # (seen in Horizon DAP feeds)
      ATDISPlanningAlertsFeed.return(
        "http://mycouncil.yass.nsw.gov.au/Horizon/@@horizondap@@/atdis/1.0/",
        "UTC",
        options.merge(flakey: true)
      )
    end

    it "should not error half way through processing" do
      # TODO: This doesn't work as expected
      # But I have faked the response in the cassette
      # allow_any_instance_of(ATDIS::Models::Page).to
      # receive(:next_page).and_raise(
      #   RestClient::InternalServerError.new("500 Internal Server Error"))
      # TODO: Expectation that a HTTP 500 on the second page still allows several errors to process
      expect(records.length).to eq 20
    end
  end
end
