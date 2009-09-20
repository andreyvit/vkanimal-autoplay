require 'rubygems'
require 'json'
require 'socket'
require 'net/http'
require 'yaml'

# $victim_vkid = "618941"
# $victim_sessionid = "972c103ec28e46517bbb90fff5d17070"
# $scarer_vkid = "50780155"
# $scarer_sessionid = "4bc39883dc4ecc07e51c9d96a284ed0b"

$victim_vkid = "2725560" # fujiwara_kumiko@mail.ru
$victim_sessionid = "972c103ec28e46517bbb90fff5d17070"
$scarer_vkid = "40686944" # marythefox@mail.ru
$scarer_vkid = "49879070" # luainel@inbox.ru
$scarer_sessionid = "4bc39883dc4ecc07e51c9d96a284ed0b"


$log = open("log.txt", "w")

def call_api sid, raw_data
  sleep 0.3  # don't be too fast
  http = Net::HTTP.new('vkanimal.rekoo.com', 80)

  headers = {
    'Cookie' => "sessionid=#{sid}",
    'Referer' => 'http://cs4130.vkontakte.ru/u3470167/35487e7127adca.zip',
    'Content-Type' => 'application/x-www-form-urlencoded'
  }
  
  request_data = "#{raw_data}&sessionid=#{sid}"
  
  $log.puts 
  $log.puts "*" * 100
  $log.puts request_data
  $log.flush

  resp, data = http.post('/get_api/', request_data, headers)

  if data.nil?
    $log.puts "!" * 100
    $log.puts "#{resp.code} #{resp.message}"
    puts "API call failed with response: #{resp.code} #{resp.message}"
    exit
  end

  j = JSON.parse(data)
  $log.puts "-" * 100
  $log.puts YAML.dump(j)
  $log.flush
  return j
end

class Animal
  attr_reader :index
  
  def initialize index, animal
    @index = index
    @scared = animal['is_scare']
    @type = animal['animal_type']
    @state = animal['state']
    
    increment_fruit = animal['increment_fruit']
    total_fruit = animal['total_fruit']
    @coolness = increment_fruit / (total_fruit - increment_fruit) * 100
  end
  
  def adult?
    @state == 'adult' || @state == 'young'
  end
  
  def scared?
    @scared
  end
  
  def cool?
    @coolness >= 99.9
  end
  
  def should_scare?
    adult? && !cool? && !scared?
  end
  
  def should_cure?
    scared?
  end
  
  def to_s
    "#{@type} \##{@index} state:#{@state} coolness:#{@coolness}% scared:#{if scared? then 'YES' else 'NO' end}"
  end
  
end

class OutOfScares < Exception
  
end

def fetch_animals(sid, vkid, target_vkid)
  result = []
  response = call_api(sid, "config=false&uid=#{target_vkid}&method=user%2Eget%5Fscene&store=false&rekoo%5Fkiller=#{vkid}&scene%5Ftype=ranch")
  animals = response['data']['ranch']['animals']['main']
  animals.collect { |index, animal| Animal.new(index, animal) }
end

def scare_animal(sid, vkid, target_vkid, animal_key)
  puts "Scaring animal #{animal_key}..."
  result = call_api(sid, "method=fold%2Efriend%2Escare&land%5Findex=#{animal_key}&scene%5Ftype=ranch&friend%5Fid=#{target_vkid}&rekoo%5Fkiller=#{vkid}&land%5Fbelong=main")
  raise OutOfScares.new if result['return_code'] == 2
end

def cure_animal(sid, vkid, animal_key)
  puts "Curing animal #{animal_key}..."
  call_api(sid, "land%5Findex=#{animal_key}&rekoo%5Fkiller=#{vkid}&land%5Fbelong=main&method=fold%2Ecure&scene%5Ftype=ranch")
end

iteration = 1
loop do
  begin
    puts "Iteration #{iteration}. Getting victim's state..."
    animals = fetch_animals($scarer_sessionid, $scarer_vkid, $victim_vkid)
    for animal in animals
      puts "- #{animal}"
    end
  
    animals_to_scare = animals.find_all { |a| a.should_scare? }
    puts "#{animals_to_scare.size} animal(s) to scare."
    for animal in animals_to_scare
      scare_animal($scarer_sessionid, $scarer_vkid, $victim_vkid, animal.index)
    end
  rescue OutOfScares => e
    puts "Out of scarers! Please login as another user for scaring."
    exit
    # redo
  end
  
  puts "Scaring complete."
  sleep 1
  
  puts "Getting victim's state..."
  animals = fetch_animals($victim_sessionid, $victim_vkid, $victim_vkid)
  for animal in animals
    puts "- #{animal}"
  end

  animals_to_cure = animals.find_all { |a| a.should_cure? }
  puts "#{animals_to_cure.size} animal(s) to cure."
  for animal in animals_to_cure
    cure_animal($victim_sessionid, $victim_vkid, animal.index)
  end
  
  puts "Curing complete."
  
  break if animals_to_scare.empty? && animals_to_cure.empty?
  iteration += 1
end
