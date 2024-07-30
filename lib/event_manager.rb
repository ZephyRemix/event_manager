require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_number(homephone)
  stripped_num = homephone.gsub(/\D/, "")

  return 'Inaccurate phone number' if stripped_num.length < 10 || stripped_num.length > 11

  if stripped_num.length == 11 
    return stripped_num[0] == "1" ? stripped_num[1..10] : 'Inaccurate homephone number'
  end 

  stripped_num
end 

def update_peak_hour(date_time, registration_peak_hour)
  registration_time = Time.strptime(date_time, "%m/%d/%Y %k:%M")
  registration_peak_hour[registration_time.hour] += 1
  puts registration_peak_hour.inspect
end 

def get_peak_hour(registration_peak_hour)
  puts "Peak hour is: #{registration_peak_hour.key(registration_peak_hour.values.max)}"
end

def update_peak_day_of_week(date, registration_peak_day_of_week)
  date_hash = Date._parse(date)
  registration_peak_day_of_week[Date.new(date_hash[:year], date_hash[:mday], date_hash[:mon]).wday] += 1
end 

def get_peak_day_of_week(registration_peak_day_of_week)
  peak_day_index = registration_peak_day_of_week.key(registration_peak_day_of_week.values.max)
  days_of_week = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
  
  puts "Peak day of week is: #{days_of_week[peak_day_index]}"
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

puts 'EventManager initialized.'

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
registration_peak_hour = Hash.new(0)
registration_peak_day_of_week = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  # puts clean_phone_number(row[:homephone])
  
  update_peak_hour(row[:regdate], registration_peak_hour)
  update_peak_day_of_week(row[:regdate].split(" ")[0], registration_peak_day_of_week)

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  
  save_thank_you_letter(id, form_letter)
end

get_peak_hour(registration_peak_hour)
get_peak_day_of_week(registration_peak_day_of_week)