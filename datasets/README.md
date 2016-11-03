## Dataset Models

This directory has a list of dataset models that we use.  Here's a brief description of each

### heroku.db-server.json

The heroku db server dataset, so we can capture the CPU, memory and I/O related metrics of db server.

### heroku.db.json

The heroku db dataset, so we can capture the database metrics of the database connection we're using. _This is different from heroku.db-server.json as the other one is about the underlying system metrics rather than database metrics._

### heroku.load.json

The heroku dyno load dataset, so we can capture the CPU load metrics of dynos over last one minute, five minutes and fifteen minutes.

### heroku.memory.json

The heroku dyno memory dataset, so we can capture the memory metrics of dynos

### heroku.pg-backup.json

The heroku postgres backup dataset, so we can capture the postgres database backup information over time.

### papertrail.reqs.json

The Requests dataset, so we can capture the request path, the number (1), the request speed and the timestamp.  This will allow us to display basic graphs like API Count, API Avg response times, and totals.

### runscope.dash.json

This schema attempts to mimic the dashboard of the Runscope web interface, showing the name of a given test, the result of the last run, the time of the last run, the success ratio of tests over the past 20 tests, and the average response time of the last test
