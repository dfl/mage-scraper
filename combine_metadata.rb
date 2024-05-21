require "multi_exiftool"
require "active_support/core_ext/hash/indifferent_access"

# image_dir = "./backup/test"
image_dir = "/Users/dfl/Library/CloudStorage/Dropbox/stable diffusion/mage backup/mogrify"
image_files = Dir[File.join image_dir, '**', '*.jpg']
# image_files = `find "#{image_dir}" -mtime +1`.split("\n")
total_files = image_files.size
json_dir = "/Users/dfl/Library/CloudStorage/Dropbox/stable diffusion/mage backup/metadata"

batch = MultiExiftool::Batch.new
options = {overwrite_original: true}

image_files.each_with_index do |filename, idx|
  puts "#{idx}/#{total_files}"
  json_file = File.join(json_dir, File.basename(filename + ".json"))
  if File.exist?(json_file)
    json = JSON.parse(File.read(json_file)).with_indifferent_access
    json[:model] = json[:model].sub("stable-diffusion ",'') # cleanup
    params = json.to_json #.encode('utf-8')
    batch.write filename, {usercomment: params}, options
  else
    puts "missing metadata for #{filename}"
  end
end
if batch.execute
  puts 'ok'
else
  puts batch.errors
end

# `rm #{image_dir}/*.*_original`

# reader = MultiExiftool::Reader.new
# reader.filenames = image_files
# results = reader.read
# unless reader.errors.empty?
#   $stderr.puts reader.errors
# end
# results.each do |values|
#   # p values
#   puts "#{values.file_name}: #{values.usercomment}"
# end
