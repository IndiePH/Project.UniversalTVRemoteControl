# TCL Validation Matrix

## Runtime flags

- `--dart-define=TCL_LEGACY_WIFI_ENABLED=false` (default)
- `--dart-define=TV_HOST_OVERRIDE=<tv-ip>` for direct test targeting

## Protocol checklist

### `androidTv` (generic Google/Android TV protocol)

- [ ] mDNS discovery returns `TvBrand.androidTv` devices across OEMs
- [ ] Pairing shows 6-char hex code prompt and succeeds
- [ ] Core keys: power, d-pad, home, back, menu
- [ ] Text input works in focused TV field

### `roku` (generic Roku ECP protocol)

- [ ] SSDP `ST: roku:ecp` discovery surfaces Roku devices across OEMs
- [ ] Pairing succeeds when "Control by mobile apps" is enabled
- [ ] Core keys: power, d-pad, home, back, menu
- [ ] App shortcuts: Netflix, Prime Video, Disney+, YouTube

### `tcl_legacy_wifi` (experimental)

- [ ] Manual add by IP works on port 4123
- [ ] Core keys: power, d-pad, home, back, menu
- [ ] Volume and channel keys work
- [ ] Known limitations recorded per model/firmware

## Release gate

- Legacy Wi-Fi stays experimental until at least one physical TCL model passes
  all legacy rows above.
- Do not enable `TCL_LEGACY_WIFI_ENABLED=true` in production builds before
  hardware sign-off.
