require 'mongo'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'

$admin = Mongo::Connection.new('localhost', 30000)['admin']
$connection_cache = {}

def connect_to_replica_set(uri, hosts)
  $connection_cache[uri] ||= Mongo::MongoReplicaSetClient.new(hosts)['admin']

  $connection_cache[uri]
end

def connect_to_mongod(host)
  host, port = host.split(':')
  $connection_cache[host] ||= Mongo::Connection.new(host, port)['admin']

  $connection_cache[host]
end

get '/' do
  erb :index
end

get '/shards' do
  $admin.command(listShards: 1).to_json
end

get '/replica_set' do
  hosts = params[:host].split('/').last.split(',')
  connect_to_replica_set(params[:host], hosts).command(replSetGetStatus: 1).to_json
end

get '/server' do
  connect_to_mongod(params[:host]).command(serverStatus: 1).to_json
end

__END__

@@ layout
<html>
  <head>
    <title>Dashboard</title>
    <script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
    <script src="//cdnjs.cloudflare.com/ajax/libs/handlebars.js/1.3.0/handlebars.js"></script>
    <script src="//ajax.googleapis.com/ajax/libs/jqueryui/1.10.2/jquery-ui.min.js"></script>
    <link rel="stylesheet" href="http://ajax.googleapis.com/ajax/libs/jqueryui/1.10.1/themes/base/jquery-ui.css" />
    <script>
      $(document).ready(function() {
        getShards();
        bindHandler();
      });

      var shards = {};

      var bindHandler = function() {
        $(document).on('click', '[data-action]', function(e) {
          var target = $(e.currentTarget);
          eval(target.data('action'))(target.data('value'));
        });
      };

      var getShards = function() {
        $.getJSON('/shards').success(function(result) {
          var template = Handlebars.compile($('#shard-template').html());
          $('#shards').html(template(result));

          $(result.shards).each(function(index, item) { shards[item._id] = item; });
        });
      };

      var openReplicaSet = function(name) {
        var replicaSet = shards[name];
        var container = getContainer('replica_set', replicaSet._id);

        createContainer(container, name);
        loadReplicaSet(replicaSet, container);
      };

      var loadReplicaSet = function(replicaSet, container) {
        $.getJSON('/replica_set', { host: replicaSet.host })
        .success(function(result) {
          var template = Handlebars.compile($('#replica-set-template').html());
          $('#' + container).html(template(result));
        })
        .error(function() {
          $('#' + container).html('N/A');
        });

        if ($('#' + container).length > 0) {
          window.setTimeout(function() {
            loadReplicaSet(replicaSet, container)
          }, 1000);
        }
      };

      var openServer = function(host) {
        var container = getContainer('server', host);

        createContainer(container, host);
        loadServer(host, container);
      };

      var loadServer = function(host, container) {
        $.getJSON('/server', { host: host })
        .success(function(result) {
          result.parameters = [];
          for(key in result) {
            result.parameters.push({ key: key, value: JSON.stringify(result[key]) });
          }

          var template = Handlebars.compile($('#server-template').html());
          $('#' + container).html(template(result));

          if ($('#' + container).length > 0) {
            window.setTimeout(function() {
              loadServer(host, container)
            }, 1000);
          }
        })
        .error(function() {
          $('#' + container).html('N/A');
        });;
      };

      var getContainer = function(type, value) {
        return type + '_' + value.replace(/\./g, '_').replace(/:/, '');
      };

      var createContainer = function(id, title) {
        if ($('#' + id).length > 0) {
          return;
        } else {
          $('body').append($('<div id="' + id + '" title="' + title + '"></div>'));
          $('#' + id).dialog({ appendTo: $('body'), close: function(e, ui) {
            $(this).dialog('destroy').remove()
          } });
        }
      };
    </script>
  </head>

  <body>
    <h1>Shards</h1>
    <section id="shards"></section>

    <script id="shard-template" type="text/x-handlebars-template">
      {{#each shards}}
        <a href="javascript:void(0);" data-action="openReplicaSet" data-value="{{_id}}">{{_id}}</a>
      {{/each}}
    </script>

    <script id="replica-set-template" type="text/x-handlebars-template">
      <table>
        <tr>
          <th>Name</th>
          <th>State</th>
          <th>Health</th>
          <th>Uptime</th>
          <th>OPTimeDate</th>
        </tr>
        {{#each members}}
          <tr>
            <td><a href="javascript:void(0);" data-action="openServer" data-value="{{name}}">{{name}}</td>
            <td>{{stateStr}}</td>
            <td>{{health}}</td>
            <td>{{uptime}}</td>
            <td>{{optime}}</td>
          </tr>
        {{/each}}
      </table>
    </script>

    <script id="server-template" type="text/x-handlebars-template">
      <table>
        <tr>
          <th>Key</th>
          <th>Value</th>
        </tr>
        {{#each parameters}}
          <tr>
            <td>{{key}}</td>
            <td>{{value}}</td>
          </tr>
        {{/each}}
      </table>
    </script>
  </body>
</html>

@@index
huhu
