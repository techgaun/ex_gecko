# ex_gecko [![Build Status](https://semaphoreci.com/api/v1/brucewang/ex_gecko/branches/master/badge.svg)](https://semaphoreci.com/brucewang/ex_gecko)

Elixir SDK to communicate with Geckoboard API, primarily with their new API for [datasets](https://developer-beta.geckoboard.com/).  The SDK is initially based off of the node.js implementation described [here](https://developer-beta.geckoboard.com/nodejs/) and source [here](https://github.com/geckoboard/geckoboard-node)

## Usage

You can use the functions in `ExGecko.Api` for making requests to RESTful api of Geckoboard. There are shorthand functions that wrap the common get requests on the Geckboard resources.

Be sure you set the environment variable before you use it

`export GECKO_API_KEY=<key>`

or you can run the mix task included here to dump various datapoints into your existing dataset

`mix load_data -t papertrail -d mydataset`


### Examples
```elixir

__Ensure authention works__
ExGecko.Api.ping

__Find or create the dataset__
ExGecko.Api.find_or_create("mydataset", %{"fields" => %{"path" => %{"type" => "string", "name" => "Request Path"}, "speed" => %{"type" => "number", "name" => "Request Speed"}}})

__Replace data in dataset__
ExGecko.Api.put("mydataset", [{"timestamp":"2016-07-26T12:00:00Z", "path":"/api/mycall", "speed": 511, "number":1}, {"timestamp":"2016-07-26T12:15:00Z", "path":"/api/myslowcall", "speed": 1532, "number":1}])

__Delete dataset__
ExGecko.Api.delete("mydataset")

```

### Datasets

This SDK takes advantage of a new API provided by GeckoBoard, which allows for much easier data manipulation and charting.  By creating an adapter (see below), we can interact with a variety of services, and transform them to a simple format that we can send to the datasets api.  This will then allow us to create any charts.  An example of this can be seen on BrighterLink's public [geckoboard](https://brighterlink.geckoboard.com/edit/dashboards/197875)

### Adapters

A key feature is the ability of the sdk to parse data from known sources of information.  This lets you interact with the raw data from the source and convert it into the format that Geckoboard expects.

* Papertrail - integrates with the papertrail cli to pump out log data, specifically needed for the reqs dataset.
