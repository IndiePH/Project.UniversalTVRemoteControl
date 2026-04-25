abstract interface class TransportCommand {
  Future<void> execute();
}

abstract interface class TransportCommandFactory {
  TransportCommand getCommand(String deviceId, String keyCode);
}
