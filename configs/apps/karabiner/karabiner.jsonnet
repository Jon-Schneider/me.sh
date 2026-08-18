local global = import 'complex-modifications/global.libsonnet';
local machine = import 'local.libsonnet';

{
  profiles: [
    {
      name: 'Default profile',
      selected: true,
      virtual_hid_keyboard: {
        country_code: 0,
        keyboard_type_v2: 'ansi',
      },
      simple_modifications: [
        { from: { consumer_key_code: 'al_terminal_lock_or_screensaver' }, to: [{ key_code: 'escape' }] },
        { from: { key_code: 'caps_lock' }, to: [{ key_code: 'escape' }] },
      ],
      fn_function_keys: [
        { from: { key_code: 'f3' }, to: [{ key_code: 'mission_control' }] },
        { from: { key_code: 'f4' }, to: [{ key_code: 'launchpad' }] },
        { from: { key_code: 'f5' }, to: [{ key_code: 'illumination_decrement' }] },
        { from: { key_code: 'f6' }, to: [{ key_code: 'illumination_increment' }] },
      ],
      complex_modifications: {
        // Machine-private rules first so they win over the shared core.
        rules: machine.rules + global.rules,
      },
    },
  ],
}
