require 'mongo'

connection = Mongo::Connection.new
db = connection['test']
collection = db['benchmark']

payload = 'x' * 1024 * 500

(0..10000).each do |i|
  collection.insert({ i: i, d: payload })
end
