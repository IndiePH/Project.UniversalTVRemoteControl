/// Builds the SSAP request payload sent on the main WebSocket channel.
///
/// Extracted as a pure function so message format can be validated in unit
/// tests without a live socket.
Map<String, dynamic> buildLgSsapRequest({
  required String requestId,
  required String uri,
  required Map<String, Object?> payload,
}) {
  return <String, dynamic>{
    'type': 'request',
    'id': requestId,
    'uri': uri,
    'payload': payload,
  };
}

/// Builds the registration manifest sent immediately after WebSocket connect.
///
/// [clientKey]: include a previously issued client-key for silent reconnection.
/// Without it, the TV shows an on-screen pairing prompt.
///
/// The 39-permission set and [serial] are required by the LG webOS pairing
/// protocol. Fewer permissions causes a 401 response; changing [serial] breaks
/// the RSA-SHA256 signature check on firmware that enforces it.
Map<String, dynamic> buildLgRegisterPayload({String? clientKey}) {
  return <String, dynamic>{
    'type': 'register',
    'id': 'register_0',
    'payload': <String, dynamic>{
      'forcePairing': false,
      'pairingType': 'PROMPT',
      'client-key': ?clientKey,
      'manifest': <String, dynamic>{
        'manifestVersion': 1,
        'appVersion': '1.1',
        'signed': <String, dynamic>{
          'created': '20140509',
          'appId': 'com.lge.test',
          'vendorId': 'com.lge',
          'localizedAppNames': <String, String>{'': 'LG Remote App'},
          'localizedVendorNames': <String, String>{'': 'LG Electronics'},
          'permissions': <String>[
            'TEST_SECURE',
            'CONTROL_INPUT_TEXT',
            'CONTROL_MOUSE_AND_KEYBOARD',
            'READ_INSTALLED_APPS',
            'READ_LGE_SDX',
            'READ_NOTIFICATIONS',
            'SEARCH',
            'WRITE_SETTINGS',
            'WRITE_NOTIFICATION_ALERT',
            'CONTROL_POWER',
            'READ_CURRENT_CHANNEL',
            'READ_RUNNING_APPS',
            'READ_UPDATE_INFO',
            'UPDATE_FROM_REMOTE_APP',
            'READ_LGE_TV_INPUT_EVENTS',
            'READ_TV_CURRENT_TIME',
          ],
          'serial': '2f930e2d2cfe083771f68e4fe7bb07',
        },
        'permissions': <String>[
          'LAUNCH',
          'LAUNCH_WEBAPP',
          'APP_TO_APP',
          'CLOSE',
          'TEST_OPEN',
          'TEST_PROTECTED',
          'CONTROL_AUDIO',
          'CONTROL_DISPLAY',
          'CONTROL_INPUT_MEDIA_RECORDING',
          'CONTROL_INPUT_MEDIA_PLAYBACK',
          'CONTROL_POWER',
          'CONTROL_INPUT_JOYSTICK',
          'CONTROL_INPUT_KEYBOARD',
          'CONTROL_INPUT_MOUSE',
          'CONTROL_INPUT_TEXT',
          'READ_APP_INFO',
          'READ_CURRENT_CHANNEL',
          'READ_INPUT_DEVICE_LIST',
          'READ_INPUT_DEVICE_STATUS',
          'READ_RUNNING_APPS',
          'READ_TV_CHANNEL_LIST',
          'WRITE_NOTIFICATION_ALERT',
          'CREATE_TOAST_NOTIFICATION',
        ],
      },
    },
  };
}
