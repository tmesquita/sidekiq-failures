module Sidekiq
  module Failures
    module WebExtension

      def self.registered(app)
        app.helpers do
          def find_template(view, *a, &b)
            dir = File.expand_path("../views/", __FILE__)
            super(dir, *a, &b)
            super
          end
        end

        app.get "/failures" do
          if params[:clear_jobs] && (params[:clear_jobs].eql? "true")
            redis = Redis.new
            redis.del 'failed'
          end

          @count = (params[:count] || 25).to_i
          (@current_page, @total_size, @messages) = page("failed", params[:page], @count)
          @messages = @messages.map { |msg| Sidekiq.load_json(msg) }

          slim :failures
        end
      end
    end
  end
end
