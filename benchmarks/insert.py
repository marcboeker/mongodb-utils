from pymongo import MongoClient

connection = MongoClient()
db = connection.test
collection = db.benchmark

payload = 'x' * 1024 * 500

for i in range(0, 10000):
  collection.insert({ 'i': i, 'd': payload })

