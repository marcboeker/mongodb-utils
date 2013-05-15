require 'mongo'
require 'fileutils'

class MongoProcess
  def create_data_dir(hostname)
    path = "#{@base_path}/#{hostname}"
    FileUtils.mkdir_p(path)

    path
  end

  def run_command(cmd)
    proc = IO.popen(cmd)
    puts "[#{proc.pid}] running: #{cmd}"
  end
end

class MongoS < MongoProcess
  def initialize(base_path, host, number, config_servers)
    @base_path = base_path
    @host = host
    @number = number
    @config_servers = config_servers

    @port = calculate_port
    @path = create_data_dir("mongos_#{number}")
  end

  attr_reader :host, :port

  def start
    config_servers = @config_servers.map { |c| c.uri }.join(',')
    run_command("mongos --configdb #{config_servers} --port #{@port} --chunkSize 1")
    sleep 10
  end

  protected

  def calculate_port
    30000 + @number
  end
end

class MongoD < MongoProcess
  def initialize(base_path, host, replica_set, member)
    @base_path = base_path
    @host = host
    @replica_set = replica_set
    @member = member

    @port = calculate_port

    @path = if @replica_set
      create_data_dir("data_#{replica_set}_#{member}")
    else
      create_data_dir("data_#{member}")
    end
  end

  attr_reader :host, :port

  def start
    replica_set = @replica_set ? "--replSet rs#{@replica_set}" : ''
    run_command("mongod --dbpath #{@path} --bind_ip #{host} --port #{@port} --smallfiles --noprealloc --rest #{replica_set}")
    sleep 2
  end

  def uri
    "#{@host}:#{@port}"
  end

  protected

  def calculate_port
    10000 + (@replica_set ? @replica_set * 10 : 0) + @member
  end
end

class MongoConfig < MongoProcess
  def initialize(base_path, host, number)
    @base_path = base_path
    @host = host
    @number = number

    @port = calculate_port
    @path = create_data_dir("config_#{number}")
  end

  attr_reader :host, :port

  def start
    run_command("mongod --configsvr --dbpath #{@path} --bind_ip #{host} --port #{@port}")
  end

  def uri
    "#{@host}:#{@port}"
  end

  protected

  def calculate_port
    20000 + @number
  end
end

class ReplicaSet
  def initialize(base_path, set, hosts)
    @base_path = base_path
    @set = set
    @hosts = hosts

    @members = []
  end

  def start
    @hosts.each_with_index { |host,i| start_mongod(host, i) }
    initiate_replica_set
    sleep 20
  end

  def uri
    hosts = @members.map { |m| m.uri }.join(',')

    "rs#{@set}/#{hosts}"
  end

  protected

  def start_mongod(host, i)
    mongod = MongoD.new(@base_path, host, @set, i)
    mongod.start

    @members << mongod
  end

  def as_config_object
    hosts = []
    @members.each_with_index do |m,i|
      hosts << { _id: i, host: m.uri }
    end

    hosts
  end

  def initiate_replica_set
    conf = { _id: "rs#{@set}", members: as_config_object }

    con = connect_to_first_member
    con['admin'].command({ replSetInitiate: conf })
  end

  def connect_to_first_member
    Mongo::MongoClient.new(@members.first.host, @members.first.port)
  end
end

class ShardingCluster
  def initialize(opts)
    @base_path = opts[:base_path]
    @config_servers = opts[:config_servers]
    @mongos = opts[:mongos]
    @replica_set_members = opts[:replica_set_members]
    @standalone_members = opts[:standalone_members]
    @db = opts[:db]
    @collections = opts[:collections]

    @con = nil
    @started_config_servers = []
    @started_replica_sets = []
    @started_standalones = []
    @started_mongos = []
  end

  def cleanup
    FileUtils.rm_rf(@base_path)

    `killall mongod`
    `killall mongos`
  end

  def start
    start_config_servers
    start_mongos
    connect_to_first_mongos

    if @standalone_members
      start_standalones
    else
      start_replica_sets
    end

    enable_sharding
    shard_collection
  end

  protected

  def start_config_servers
    @config_servers.each_with_index do |host,i|
      config_server = MongoConfig.new(@base_path, host, i)
      config_server.start

      @started_config_servers << config_server
    end

    sleep 20
  end

  def start_mongos
    @mongos.each_with_index do |host,i|
      mongos = MongoS.new(@base_path, host, i, @started_config_servers)
      mongos.start

      @started_mongos << mongos
    end
  end

  def start_replica_sets
    @replica_set_members.each_with_index do |hosts,i|
      replica_set = ReplicaSet.new(@base_path, i, hosts)
      replica_set.start

      add_shard(replica_set)

      @started_replica_sets << replica_set
    end
  end

  def start_standalones
    @standalone_members.each_with_index do |host,i|
      standalone = MongoD.new(@base_path, host, nil, i)
      standalone.start

      add_shard(standalone)

      @started_standalones << standalone
    end
  end

  def add_shard(shard)
    @con['admin'].command({ addShard: shard.uri })
  end

  def connect_to_first_mongos
    mongos = @started_mongos.first
    @con = Mongo::MongoClient.new(mongos.host, mongos.port)
  end

  def enable_sharding
    @con['admin'].command({ enableSharding: @db })
  end

  def shard_collection
    @collections.each do |item|
      @con['admin'].command({ shardCollection: "#{@db}.#{item[:collection]}", key: item[:key] })
    end
  end
end

s = ShardingCluster.new(
  base_path: '/data', # where all the data directories are created
  config_servers: ['127.0.0.1'] * 3, # start 3 config servers
  mongos: ['127.0.0.1'] * 1, # start 1 mongos
  replica_set_members: [['127.0.0.1'] * 3, ['127.0.0.1'] * 3, ['127.0.0.1'] * 3], # start 3 shards with 3 replicas each
  #standalone_members: ['127.0.0.1'] * 3,
  db: 'test', # use 'test' db
  collections: [{ collection: 'logs', key: { number: 1 } }] # shard the collection 'logs' with 'number' as shard key
)

s.cleanup
s.start
