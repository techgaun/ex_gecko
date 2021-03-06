# ex_gecko

[![Hex version](https://img.shields.io/hexpm/v/ex_gecko.svg "Hex version")](https://hex.pm/packages/ex_gecko) ![Hex downloads](https://img.shields.io/hexpm/dt/ex_gecko.svg "Hex downloads") [![Build Status](https://travis-ci.org/techgaun/ex_gecko.svg?branch=master)](https://travis-ci.org/techgaun/ex_gecko) [![Coverage Status](https://coveralls.io/repos/github/techgaun/ex_gecko/badge.svg?branch=master)](https://coveralls.io/github/techgaun/ex_gecko?branch=master)

Elixir SDK to communicate with Geckoboard API, primarily with their new API for [datasets](https://developer.geckoboard.com/). The SDK is initially based off of the node.js implementation described [here](https://developer.geckoboard.com/nodejs/) and source [here](https://github.com/geckoboard/geckoboard-node)

## Installation

You can install ExGecko from hex by specifying `ex_gecko` in your mix.exs dependency:

```elixir
def deps do
  [{:ex_gecko, "~> 0.0.5"}]
end
```

You can install ExGecko from github as well but be aware that the master branch might not always be stable:

```elixir
def deps do
  [{:ex_gecko, github: "techgaun/ex_gecko"}]
end
```

You can also clone this repository and then run the mix tasks from within the project directory in case you do not wish to make your own separate project.

```shell
git clone git@github.com:techgaun/ex_gecko.git
mix deps.get
```

## Usage

You can use the functions in `ExGecko.Api` for making requests to RESTful api of Geckoboard. There are shorthand functions that wrap the common get requests on the Geckboard resources.

Be sure you set the environment variable before you use it

`export GECKO_API_KEY=<key>`

or you can run the mix task included here to dump various datapoints into your existing dataset

__Create a new dataset 'mynewdataset' using the datasets/reqs.json format__

`mix gecko.load -d mynewdataset -r reqs`

__Load papertrail data into geckoboard dataset 'mynewdataset'__

`mix gecko.load -t papertrail -d mynewdataset`

__Note : Currently, the Geckboard dataset only supports up to 500 records per request, and this SDK will account for this by limiting the data it will send__


### Examples

```elixir
# Ensure authentication works
ExGecko.Api.ping

# Find or create the dataset
ExGecko.Api.find_or_create("mydataset", %{"fields" => %{"path" => %{"type" => "string", "name" => "Request Path"}, "speed" => %{"type" => "number", "name" => "Request Speed"}}})

# Replace data in dataset
ExGecko.Api.put("mydataset", [{"timestamp":"2016-07-26T12:00:00Z", "path":"/api/mycall", "speed": 511, "number":1}, {"timestamp":"2016-07-26T12:15:00Z", "path":"/api/myslowcall", "speed": 1532, "number":1}])

# Append data to a dataset
ExGecko.Api.append("mydataset", [{"timestamp":"2016-07-26T12:00:00Z", "path":"/api/mycall", "speed": 511, "number":1}, {"timestamp":"2016-07-26T12:15:00Z", "path":"/api/myslowcall", "speed": 1532, "number":1}])

# Delete dataset
ExGecko.Api.delete("mydataset")

# Create a dataset (using the schema located in datasets/<type>.json)
ExGecko.Api.create_dataset("mynewdataset", "reqs")

# Push an monitor update
ExGecko.Api.push_monitor("mywidget", "Up", "2 days ago", "112 ms") # down time and response time is optional

# Push an arbitrary widget update
ExGecko.Api.push("mywidget", %{"data" => <geckodata>})

```

### Datasets

This SDK takes advantage of a new API provided by GeckoBoard, which allows for much easier data manipulation and charting. By creating an adapter (see below), we can interact with a variety of services, and transform them to a simple format that we can send to the datasets api. This will then allow us to create any charts.  An example of this can be seen on BrighterLink's public [geckoboard](https://brighterlink.geckoboard.com/loop/777165AF8CFDA675).

There are number of datasets available right now. You can read more about our datasets [here](datasets/README.md)

### Adapters

A key feature is the ability of the sdk to parse data from known sources of information.  This lets you interact with the raw data from the source and convert it into the format that Geckoboard expects.

* Papertrail - integrates with the papertrail cli to pump out log data, specifically needed for the reqs dataset.

* Heroku - integrates with the heroku cli to pump out CPU load, memory stats and postgres DB stats

* Runscope - integrates with Runscope API to pull test results

#### Papertrail

The papertrail adapter requires [papertrail-cli](https://github.com/papertrail/papertrail-cli) to be installed. Once installed, make sure you configure papertrail so that it can fetch data.

```shell
echo "token: 123456789012345678901234567890ab" > ~/.papertrail.yml
```

Now you can use the `mix gecko.load` task to load papertrail logs:

```shell
mix gecko.load -d api.reqs -r papertrail.reqs # create dataset for papertrail request logs

mix gecko.load -d api-reqs -t papertrail # load data to datasets
```

Papertrail adapter supports either of heroku router data format or the
[plug_logger_json](https://github.com/bleacherreport/plug_logger_json) data format. The `user_id` field in papertrail
dataset definition is used to co-relate the requests with the user.

#### Heroku

The heroku adapter requires [heroku-cli](https://github.com/heroku/heroku) to be installed. Once you configure heroku, you can use heroku adapter as below:

```shell
mix gecko.load -d heroku-api.load -r heroku.load # create dataset for load
mix gecko.load -d heroku-api.memory -r heroku.memory # create dataset for memory
mix gecko.load -d heroku-api-db.stats -r heroku.db # create dataset for db stats

# run the actual loading of data as below:
mix gecko.load -d heroku-api.load -t heroku -a type=load,lines=1000
mix gecko.load -d heroku-api.memory -t heroku -a type=memory,app=your-heroku-app
mix gecko.load -d heroku-api-db.stats -t heroku -a "type=db"
```

The heroku adapter supports following comma separated lists of arguments:

* `type` : One of `db`, `db-server`, `pg-backup`, `memory` and `load`
* `app` : The heroku app you are wishing to pump logs from
* `lines` : Number of lines to pull from logs (not applicable for `pg-backup`)

The available dataset names that can be passed as `-r` argument: `heroku.db`, `heroku.db-server`, `heroku.load`, `heroku.memory`, `heroku.pg-backup`.

#### Runscope

The runscope adapter requires you to have an access_token from their OAuth2

```shell
export RUNSCOPE_TOKEN=<1234567890>
```

For runscope, the following datasets may be initialized:
```shell
mix gecko.load -d <dataset_name> -r runscope.dash # Mimics the dashboard of the Runscope web interface
```

Then, to load data to the above datasets, you must use the following arguments:

* `test_id` : The ID of the test that you would like to add/update in the Geckoboard dataset
* `bucket_id` : The ID of the testing bucket

For example, you may add/update the dataset as below:

```shell
mix gecko.load -d <dataset_name> -t runscope -a test=<test id>bucket_id=<bucket id>
```


You may also use Geckoboard's legacy Uptime widget to briefly summarize the status of your Runscope tests. To do so, simply specify the
widget key, as well as the test ID of the target test:

```shell
# updates a monitor widget with your runscope last passed test data
mix gecko.load -w <widget key> -t runscope -a test=<test id> bucket_id=<bucket id>
```
