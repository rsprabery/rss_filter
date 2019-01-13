# rss_filter

A time based RSS filter. Takes articles and puts them in instapaper after a
time period as passed.

## Installation

**Run**: `crystal run --link-flags "-L$(brew --prefix)/opt/openssl/lib -L $(brew --prefix)/opt/libgc/lib -L $(brew --prefix)/opt/libevent/lib" src/rss_filter.cr`

**Build**: `crystal build --link-flags "-L $(brew --prefix)/opt/openssl/lib -L $(brew --prefix)/opt/libgc/lib -L $(brew --prefix)/opt/libevent/lib" src/rss_filter.cr`

## Usage

Using the filter is as easy as starting the binary and letting it run. I
typically run it within tmux and tee the output to disk. In the future, I
may add a launchd and systemd init scripts, but for now tmux is good enough.

To keep secrets out of the repo, you need to set env vars for your instapaper
username and password before starting the filter.

```bash
export INSTA_USERNAME=???
export INSTA_PWD=???
./rss_filter | tee rss_filter.log
```

To run the ruby version: `ruby ruby_version/rss_filter.rb`.

## Development

All the source lives in `srs/rss_filter.cr`. A ruby comparison is at
`ruby_version/rss_filter.rb`.

## Contributing

1. Fork it (<https://github.com/your-github-user/rss_filter/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Read Sprabery](https://github.com/rsprabery) - creator and maintainer
