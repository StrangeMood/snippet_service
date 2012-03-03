require 'rack/uploads'
require 'securerandom'

# add middleware for file uploads and set nginx special variables
use Rack::Uploads, :nginx => [{:tmp_path => 'path', :filename => 'name'}]

module Rack
  class Uploader

    def call env
      request = Rack::Request.new(env)
      if request.request_method == 'POST'
        out = env['rack.uploads'].map do |upload|
          # generate persistent filename
          filename = SecureRandom.hex(20) + ::File.extname(upload.filename)
          upload.cp("/tmp/uploads/#{filename}")
          filename
        end
        # return all persistent files names to client
        [200, {}, out]
      else
        # send client to hell in case of GET requests
        [200, {}, ['GO OUT']]
      end
    end

  end
end

# put our service on /upload path
map '/upload' do
  run Rack::Uploader.new
end