require 'mongo'

con = Mongo::MongoClient.new('127.0.0.1', 30000)
$db = con['test']
$col = $db['logs']

def insert_data
  payload = 'x' * 1024# * 128
  (0...100000).each do |i|
    $col.insert({ date: Time.now, number: i, data: payload })
    puts i
  end
end

def query
  while true
    #p $col.find({ number: { '$mod' => [rand(1..100000), 0] } }, fields: { number: 1 }).skip(1).first # slooooooow
    p $col.find({ number: rand(1..100000) }, fields: { number: 1 }).first
  end
end

def insert_continuously
  payload = 'x' * 1024 * 1024
  i = 0
  while true
    $col.insert({ date: Time.now, number: i, data: payload })
    #$db.get_last_error(w: 3)
    puts i

    i += 1
  end
end

#insert_data
#query
insert_continuously
