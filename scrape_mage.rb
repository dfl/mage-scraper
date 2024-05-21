require 'ferrum'
require 'json'
require 'open-uri'

# monkeypatch Ferrum to fix JSON parsing issue with bad emojis
module Ferrum
  class Client
    class WebSocket
      def on_message(event)
        begin
          data = JSON.parse(event.data)
        rescue JSON::ParserError
          data = JSON.parse(event.data.gsub(/\\u\w{4}/,''))
        end
        @messages.push(data)

        output = event.data
        if SKIP_LOGGING_SCREENSHOTS && @screenshot_commands[data["id"]]
          @screenshot_commands.delete(data["id"])
          output.sub!(/{"data":"(.*)"}/, %("Set FERRUM_LOGGING_SCREENSHOTS=true to see screenshots in Base64"))
        end

        @logger&.puts("    ◀ #{Utils::ElapsedTime.elapsed_time} #{output}\n")
      end
    end
  end
end

USER = "XXXXXXXXX"
EMAIL = "YYYYYYYYYYY"
TOTAL_IMAGES = 11478
SAVE_IMAGES = false
profile = "https://www.mage.space/u/#{USER}"

browser = Ferrum::Browser.new(headless: false)
browser.go_to(profile)
sleep(1)
login_button = ".mantine-Avatar-root.mantine-1mgjsk8"
browser.at_css(login_button).click
sleep(1)
browser.at_xpath("//div[text()='Login']//parent::*").click
browser.at_css("input#mantine-r2").focus.type(EMAIL, :Enter)
puts "copy the magic link in your email and paste into browser bar,"
puts "then go to the page you want. also disable safe mode if desired."
puts "(when ready, touch any key to continue...)"
gets;

browser.go_to(profile)
page_y = 0
# dir = "metadata"
# page_y = 24000
# page_y = 111800
dir = "favorites"
# page_y = 335600
browser.mouse.scroll_to(0, page_y);
total = Dir[File.join dir, '**', '*'].count &File.method(:file?)
while total < TOTAL_IMAGES+100
  puts "********  scrolled to #{page_y}"
  grid = browser.at_css("div[role=grid]")
  count = grid.description["childNodeCount"]
  count.times do |i|
    if close_modal = browser.at_css(".mantine-Modal-close")
      close_modal.click
    end
    puts "Processing #{i+1}/#{count} (#{total}/#{TOTAL_IMAGES})"
    el = browser.at_css("div[role=gridcell]:nth-child(#{i+1})")
    script = %Q{ document.querySelectorAll("div[role=gridcell]:nth-child(#{i+1}) img")[0].click() }
    browser.execute(script)
    sleep(0.3)
    modal = browser.at_css("div.mantine-Modal-modal.mantine-10dtdhv")
    params = {}
    url = modal.at_css("img")["src"]
    if SAVE_IMAGES
      params[:filename] = url.split("/").last
      File.write("#{dir}/#{params[:filename]}", URI.open(url).read)
    end
    filename = "#{dir}/#{params[:filename]}.json"
    unless File.exist?(filename)
      text = modal.inner_text
      params[:prompt] = text.match(/Rerun\nRemix\nReimage\n(.+?)\nCopy Prompt/m){$1}.chomp("\nShow more")
      params[:negative] = text.match(/Negative Prompt\n(.+?)\nShow more/){$1}
      params[:model] = text.match(/Model\n(.+?)\nModel Version\n(.+?)\nGuidance Scale/m){"#{$1} #{$2}"}
      params[:seed] = text.match(/Seed\n(.+?)\nSteps/m){$1}.to_i
      params[:cfg] = text.match(/Guidance Scale\n(.+?)\nDimensions/m){$1}.to_f
      params[:steps] = text.match(/Steps\n(\d+?)\n/m){$1}.to_i
      params[:scheduler] = text.match(/Scheduler\n(.+?)\nDate/m){$1}
      params[:dimensions] = text.match(/Dimensions\n(.+?)\nSeed/m){$1}
      p params

      File.open(filename, 'w') do |file|
        file.write(params.to_json)
      end
    else
      puts "file exists! #{filename}"
      # break
    end
  end
  total += count
  page_y += 1200
  browser.mouse.scroll_to(0, page_y)
end

# - click link to show popup
#   - download image
#   - save metadata
#   - bonus: recompress jpg and merge in metadata
