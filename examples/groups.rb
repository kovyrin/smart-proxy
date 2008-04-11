require 'hpricot'
require 'smart_proxy'

module API
  module Google
    class Groups
      def find_threads(query, options = {})
        # Get all threads from Google
        threads = find_all_threads(query, options)
    
        # Fetch threads posts
        threads = fetch_full_threads(threads)

        # Return list to the caller
        return threads
      end

    private

      # Returns all threads matching specified query
      def find_all_threads(query, options)
        cnt = options[:limit] || 10
        threads = []
        page = 0

        while (page < 10 && threads.size < cnt)
          page_threads = find_threads_page(query, page, options)
          break unless page_threads
          threads.concat(page_threads) 
          page = page + 1
        end
  
        return threads[0, cnt]
      end
  
      def find_threads_page(query, page, options)
        url = "http://groups.google.com/groups/search?q=#{CGI.escape query}&start=#{page*10}&sa=N"
        html = download_content(url)
        return nil unless html
        
        chunks = html.split('<font size="+0">')
        return nil if chunks.size < 2
    
        threads = []
        chunks.each do |chunk|
          thread = {}
          
          next unless m = chunk.match(/(\d+)\s+messages\W+(\d+)\s+authors/)
          thread[:message_count] = m[1].to_i
          thread[:authors_count] = m[2].to_i
      
          next unless m = chunk.match(/\/group\/(.*?)\/browse_thread\/thread\/([\w]+)/)
          thread[:group] = m[1]
          thread[:token] = m[2]
          
          thread[:title] = match_content(chunk, /<a[^>]+(.*?)<\/a>\s*$/)
      
          threads << thread
        end
        
        threads = filter_empty(threads) unless options[:with_empty]
        threads = filter_non_nntp(threads) if options[:nntp_only]
        threads = filter_spam(threads) unless options[:with_spam]
    
        return threads
      end
      
      def filter_empty(threads)
        results = []
        threads.each do |thread|
          results << thread if thread[:authors_count] > 1 && thread[:message_count] > 1
        end
        return results
      end
      
      def filter_non_nntp(threads)
        results = []
        threads.each do |thread|
          results << thread if thread[:group].match(/^\w+\.\w+/) && !thread[:group].match(/^google/i)
        end
        return results
      end
      
      def filter_spam(threads)
        results = []
        threads.each do |thread|
          next if thread[:group].match(/abuse/)
          results << thread unless thread[:title] && thread[:title].match(/spam/i)
        end
        return results
      end
    
      def fetch_full_threads(threads)
        results = []
        threads.each do |thread|
          thread[:posts] = fetch_thread_posts(thread)
          results << thread if thread[:posts]
          sleep(0.3) unless AppConfig.download_interfaces && AppConfig.download_interfaces.size > 0
        end
        return results
      end
      
      def fetch_thread_posts(thread)
        url = "http://groups.google.com/group/#{thread[:group]}/browse_thread/thread/#{thread[:token]}"
        content = download_content(url)
        return nil unless content
    
        chunks = content.split('<br style="font-size:8px;" clear="all">')
        return nil if chunks.size < 2
    
        posts = []
        chunks.each do |chunk|
          post = {}
          next unless token = match_content(chunk, /<a\s*name="msg_(.*?)">/i)
          
          post[:upstream_token] = thread[:token] + "-" + token
          post[:author] = match_content(chunk, /<span\s+style="color:\s*#\w{6};">(.{1,50}?)<\/span>/i)
          post[:posted_at] = match_content(chunk, /Date:\s*<b>(.*?)<\/b>/i)
          post[:title] = match_content(chunk, /Subject:\s*<b>(.*?)<\/b>/i)
          post[:body] = match_content(chunk, /<a\s*name="msg_(.*?)">(.*?)$/i, 2)
      
          post[:body].gsub!(/<br[\/]*>/, "\n")
          post[:body] = post[:body].strip_tags
          post[:body].gsub!(/\n/, "<br/>")
      
          posts << post if post[:author]
        end
    
        return posts
      end
    
      def match_content(content, regex, pos = 1)
        m = content.match(regex)
        return nil unless m
        return m[pos]
      end
    
      def get_parsed_content(url)
        content = download_content(url)
        content ? Hpricot.XML(content, :xml => true) : nil
      end
  
      def download_content(url)
        # Instantiate smart proxy
        @@downloader ||= SmartProxy.new(:interfaces => AppConfig.download_interfaces)
        @@connection ||= @@downloader.create_connection("google")
        
        tries = AppConfig.download_max_tries || 10
        while true do
          tries = tries - 1
          if tries < 1
            RAILS_DEFAULT_LOGGER.error("Error: Banned by google and can't download content in #{AppConfig.download_max_tries || 10} tries!")
            raise "Error: Banned by google and can't download content in #{tries} tries!"
          end
          
          RAILS_DEFAULT_LOGGER.info("Downloading #{url} (try ##{tries})")
          content = @@connection.download(url) rescue nil

          unless content
            RAILS_DEFAULT_LOGGER.info("No content received, trying again. Tries left: #{tries}")
            next
          end
          
          if content.match(/your query looks similar to automated requests from a computer virus or spyware application/)
            RAILS_DEFAULT_LOGGER.info("Banned by google, sleeping for 5 minutes before retry")
            sleep(300)
            next
          end

          return content
        end

        RAILS_DEFAULT_LOGGER.info("Can't download URL: #{url}") 
        return nil
      end  
    end
  end
end
