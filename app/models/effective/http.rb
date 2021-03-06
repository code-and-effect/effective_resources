module Effective
  class Http

    def self.get(endpoint, params: nil, headers: nil)
      headers = { 'Content-Type': 'application/json' }.merge(headers || {})
      query = ('?' + params.compact.map { |k, v| "$#{k}=#{v}" }.join('&')) if params.present?

      uri = URI.parse(endpoint + query.to_s)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      http.use_ssl = true if endpoint.start_with?('https')

      response = with_retries do
        puts "[GET] #{uri}" if Rails.env.development?
        http.get(uri, headers)
      end

      unless ['200', '204'].include?(response.code.to_s)
        puts("Response code: #{response.code} #{response.body}")
        return false
      end

      JSON.parse(response.body)
    end

    def self.post(endpoint, params:, headers: nil)
      headers = { 'Content-Type': 'application/json' }.merge(headers || {})

      uri = URI.parse(endpoint)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      http.use_ssl = true if endpoint.start_with?('https')

      response = with_retries do
        puts "[POST] #{uri} #{params}" if Rails.env.development?
        http.post(uri.path, params.to_json, headers)
      end

      unless ['200', '204'].include?(response.code.to_s)
        puts("Response code: #{response.code} #{response.body}")
        return false
      end

      JSON.parse(response.body)
    end

    def self.patch(endpoint, params:, headers: nil)
      headers = { 'Content-Type': 'application/json' }.merge(headers || {})

      uri = URI.parse(endpoint)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      http.use_ssl = true if endpoint.start_with?('https')

      response = with_retries do
        puts "[PATCH] #{uri} #{params}" if Rails.env.development?
        http.post(uri.path, params.to_json, headers)
      end

      unless ['200', '204'].include?(response.code.to_s)
        puts("Response code: #{response.code} #{response.body}")
        return false
      end

      JSON.parse(response.body)
    end

    def self.delete(endpoint, params: nil, headers: nil)
      headers = { 'Content-Type': 'application/json' }.merge(headers || {})
      query = ('?' + params.compact.map { |k, v| "$#{k}=#{v}" }.join('&')) if params.present?

      uri = URI.parse(endpoint + query.to_s)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      http.use_ssl = true if endpoint.start_with?('https')

      response = with_retries do
        puts "[DELETE] #{uri}" if Rails.env.development?
        http.delete(uri, headers)
      end

      unless ['200', '204'].include?(response.code.to_s)
        puts("Response code: #{response.code} #{response.body}")
        return false
      end

      JSON.parse(response.body)
    end

    private

    def self.with_retries(retries: 3, wait: 2, &block)
      raise('expected a block') unless block_given?

      begin
        return yield
      rescue Exception => e
        if (retries -= 1) > 0
          sleep(wait); retry
        else
          raise
        end
      end
    end

  end
end
