release: SKIP_OWID_AUTO_IMPORT=1 bundle exec rails db:prepare && SKIP_OWID_AUTO_IMPORT=1 bundle exec rails metrics:load_seed
web: bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}
