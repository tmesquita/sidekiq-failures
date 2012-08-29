module Sidekiq
  module Failures
    class Middleware
      def call(worker, msg, queue)
        yield
      rescue => e
        
        failed_job = check_existing_failures(msg)

        if failed_job
          data = JSON.parse Sidekiq.redis{|conn| conn.lindex(:failed, failed_job)}
          data["num_retries"] += 1
          data["failed_at"] = Time.now.strftime("%Y/%m/%d %H:%M:%S %Z")
          Sidekiq.redis { |conn| conn.lset(:failed, failed_job, Sidekiq.dump_json(data)) }
        else

          data = {
            :failed_at => Time.now.strftime("%Y/%m/%d %H:%M:%S %Z"),
            :payload => msg,
            :exception => e.class.to_s,
            :error => e.to_s,
            :backtrace => e.backtrace,
            :worker => msg['class'],
            :queue => queue,
            :num_retries => 0
          }
          Sidekiq.redis { |conn| conn.rpush(:failed, Sidekiq.dump_json(data)) }
        end


        raise
      end
      private
        def check_existing_failures(msg)
          Sidekiq.redis{|conn|
            (0..conn.llen(:failed)-1).each do |index|
              return index if JSON.parse(conn.lindex(:failed, index))["payload"]['jid'].eql? msg['jid']
            end
          }
          false
        end
    end
  end
end
