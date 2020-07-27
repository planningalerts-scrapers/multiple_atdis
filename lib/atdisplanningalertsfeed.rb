# frozen_string_literal: true

require "atdisplanningalertsfeed/version"
require "atdis"
require "scraperwiki-morph"
require "cgi"

# Top level module for gem
module ATDISPlanningAlertsFeed
  def self.fetch(url, timezone, options = {})
    feed = ATDIS::Feed.new(url, timezone)
    logger = options[:logger]
    logger ||= Logger.new(STDOUT)

    options[:lodgement_date_start] = (options[:lodgement_date_start] || Date.today - 30)
    options[:lodgement_date_end] = (options[:lodgement_date_end] || Date.today)

    # Grab all of the pages
    pages = fetch_all_pages(feed, options, logger)

    pages.each do |page|
      additional_records = collect_records(page)
      additional_records.each { |record| yield record }
      # If there are no more records to fetch, halt processing
      # regardless of pagination
      break unless additional_records.any?
    end
  end

  def self.save(url, timezone, options = {})
    fetch(url, timezone, options) do |record|
      persist_record(record)
    end
  end

  # Convenience method that returns all the records in one go
  def self.return(url, timezone, options = {})
    records = []
    fetch(url, timezone, options) { |record| records << record }
    records
  end

  def self.fetch_all_pages(feed, options, logger)
    begin
      page = feed.applications(
        lodgement_date_start: options[:lodgement_date_start],
        lodgement_date_end: options[:lodgement_date_end]
      )
    rescue RestClient::InternalServerError => e
      # If the feed is known to be flakey, ignore the error
      # on first fetch and assume the next run will pick this up
      #
      # Planningalerts itself will also notice if the median applications drops to 0
      # over time
      logger.error(e.message)
      logger.debug(e.backtrace.join("\n"))
      return [] if options[:flakey]

      raise e
    end

    unless page.pagination&.respond_to?(:current)
      logger.warn("No/invalid pagination, assuming no records/aborting")
      return []
    end

    pages = [page]
    pages_processed = [page.pagination.current]
    begin
      while (page = page.next_page)
        unless page.pagination&.respond_to?(:current)
          logger.warn("No/invalid pagination, assuming no records/aborting")
          break
        end

        # Some ATDIS feeds incorrectly provide pagination
        # and permit looping; so halt processing if we've already processed this page
        unless pages_processed.index(page.pagination.current).nil?
          logger.info("Page #{page.pagination.current} already processed; halting")
          break
        end
        pages << page
        pages_processed << page.pagination.current
        logger.debug("Fetching #{page.next_url}")
      end
    rescue RestClient::InternalServerError => e
      # Raise the exception unless this is known to be flakey
      # allowing some processing of records to take place
      logger.error(e.message)
      logger.debug(e.backtrace.join("\n"))
      raise e unless options[:flakey]
    end

    pages
  end

  def self.collect_records(page)
    page.response.collect do |item|
      application = item.application

      # TODO: Only using the first address because PA doesn't support multiple addresses right now
      address = application.locations.first.address.street + ", " +
                application.locations.first.address.suburb + ", " +
                application.locations.first.address.state  + " " +
                application.locations.first.address.postcode

      {
        council_reference: CGI.unescape(application.info.dat_id),
        address: address,
        description: application.info.description,
        info_url: application.reference.more_info_url.to_s,
        comment_url: application.reference.comments_url.to_s,
        date_scraped: Date.today,
        date_received: application.info.lodgement_date&.to_date,
        on_notice_from: application.info.notification_start_date&.to_date,
        on_notice_to: application.info.notification_end_date&.to_date
      }
    end
  end

  def self.persist_record(record)
    ScraperWikiMorph.save_sqlite([:council_reference], record)
  end
end
