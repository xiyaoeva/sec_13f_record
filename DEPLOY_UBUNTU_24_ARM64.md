# Deploy `sec_13f_record` on Ubuntu 24.04 (ARM64)

## 1) System packages

```bash
sudo apt update
sudo apt install -y git curl build-essential pkg-config \
  libssl-dev zlib1g-dev libreadline-dev libyaml-dev \
  libgmp-dev libncurses-dev libffi-dev libgdbm-dev \
  libpq-dev postgresql postgresql-contrib redis-server nodejs npm
sudo npm install -g yarn
```

## 2) Ruby 3.2.4 + Bundler

```bash
cd ~
git clone https://github.com/rbenv/rbenv.git ~/.rbenv || true
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build || true

echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

rbenv install -s 3.2.4
rbenv global 3.2.4
rbenv rehash
ruby -v
```

Then install bundler + gems:

```bash
cd ~/sec_13f_record
gem install bundler -v 2.2.25
bundle _2.2.25_ install
```

If upgrading from an older lockfile, refresh key gems for Ruby 3.2 first:

```bash
bundle _2.2.25_ update rails nio4r msgpack bootsnap pg nokogiri puma
bundle _2.2.25_ install
```

## 3) JS deps

```bash
yarn install --check-files
```

## 4) Database

Update `config/database.yml` for your PostgreSQL user/password, then:

```bash
RAILS_ENV=production bundle exec rails db:create db:migrate
```

## 5) Build assets

```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

## 6) Initialize with two quarters

```bash
RAILS_ENV=production bundle exec rake "sec_13f_record:init_two_quarters[2025,4,2026,1]"
```

## 7) Start app

```bash
RAILS_ENV=production bundle exec foreman start -f Procfile
```

Default web port is `5000` unless overridden by `PORT`.

## 8) Run keyword export

```bash
RAILS_ENV=production bundle exec rake "sec_13f_record:export_keyword[intc]"
```

CSV output dir:

`./exports/keyword_comparisons`

## 9) Update behavior

From `clock.rb`:

- Every day `05:00` America/New_York: import/process previous-day quarter filings
- Every 30 minutes at `:15` and `:45` between `07:00-20:59` America/New_York: import/process most recent filings
- Every day `23:00` America/New_York: refresh materialized views

## 10) Frontend compatibility note

This project forces `node-sass` to `sass` (Dart Sass) via Yarn `resolutions` in `package.json` to avoid `node-gyp/python2` issues on Ubuntu 24.04 ARM64.
