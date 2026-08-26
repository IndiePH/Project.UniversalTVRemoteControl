# Sony BRAVIA IP Control Validation Matrix

Manual on-device runbook for `SonyBraviaAdapter` (`TvBrand.sony`,
`SonyProtocolVariants.braviaIpControl`) — experimental, PIN-mode auth only. See
`guide-tv-remote-protocols.md`'s "Sony BRAVIA IP Control" section for the protocol
details and `references/goals/goal-sony-adapter.md` (Sub-goal C) for build history.

Nothing below has been run against real hardware yet — every protocol-level claim in
the guide comes from third-party/community sources, not Sony's own docs.

## Runtime flags

- `--dart-define=TV_HOST_OVERRIDE=<tv-ip>` for direct test targeting (bypasses discovery).

## Pairing

- [ ] SSDP discovery surfaces the TV as `TvBrand.sony` (fingerprint: `scalarwebapi`
      substring in SSDP headers — confirm it doesn't also fire on a Sony soundbar/other
      Songpal device on the same network).
- [ ] First `actRegister` call (no PIN) triggers the TV to display an on-screen PIN.
- [ ] Entering the displayed PIN completes pairing and persists a session.
- [ ] Entering a wrong PIN fails cleanly and lets the user retry.
- [ ] Reopening the app reconnects without re-prompting for a PIN (persisted session:
      cookie + Basic-Auth header both replayed correctly).
- [ ] Un-pairing and re-pairing works (session cleared, fresh `actRegister` cycle).
- [ ] Manually adding by IP resolves to this variant when the TV only speaks BRAVIA IP
      Control (not the Android TV Remote path) — exercises `ManualAddVariantProbe`.

## Command dispatch — confirmed-name IRCC keys

- [ ] D-pad: `Up` / `Down` / `Left` / `Right` / `Confirm`
- [ ] `Home`, `Return` (back)
- [ ] `VolumeUp` / `VolumeDown` / `Mute`
- [ ] `ChannelUp` / `ChannelDown`
- [ ] `Input`
- [ ] `Power` — confirm which alias the TV actually reports (`Power` vs `TvPower`); note
      the model/firmware if it's `TvPower` only, since the mapper tries `Power` first.

## Command dispatch — uncertain, needs on-device confirmation

- [ ] `menu` → mapped to `'Options'`. Compare against what the TV's own
      `getRemoteControllerInfo` response actually names — `'TopMenu'` and
      `'AndroidMenu'` are the other candidates seen in community sources. Update
      `sony_bravia_key_mapper.dart` if wrong.
- [ ] `playPause` — currently **unmapped** (no combined toggle code exists in any source
      checked). Confirm whether this specific TV's IRCC list has a real toggle name (not
      just separate `Play`/`Pause`) before considering adding it.

## App launch

- [ ] Netflix launches via `getApplicationList`/`setActiveApp` (title match: `'netflix'`).
- [ ] YouTube launches (title match: `'youtube'`).
- [ ] Prime Video — title match is a **best guess** (`'prime video'`); confirm the real
      reported title and update `SonyBraviaAdapter._appLaunchTitles` if it doesn't match
      (e.g. `'Amazon Prime Video'` would still match via substring, but confirm).
- [ ] Disney+ — same caveat, best guess (`'disney+'`).
- [ ] Tapping an app-launch button for an app *not* installed fails cleanly (no crash,
      clear error) rather than launching the wrong thing.

## Known gaps (by design, not bugs)

- PSK static-key auth is not built — only PIN-mode (`actRegister`) pairing works.
- Text input (`sendText`) is not supported — `supportsTextInput` is `false`.
- `web` (browser) has no mapping — no evidence found of a generic browser app during
  research.
- Simple IP Control (legacy TCP/20060) is out of scope entirely.

## Release gate

- Stays experimental until at least one physical Sony BRAVIA model passes every row
  above, with any wrong IRCC names or app titles corrected in
  `sony_bravia_key_mapper.dart` / `SonyBraviaAdapter._appLaunchTitles`.
