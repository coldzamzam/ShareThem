import 'package:bonsoir/bonsoir.dart';

class SharingDiscoveryService {
  static final BonsoirService service = BonsoirService(
    name: 'SharingService', // Put your service name here.
    type:
        '_sharing-service._tcp', // Put your service type here. Syntax : _ServiceType._TransportProtocolName. (see http://wiki.ros.org/zeroconf/Tutorials/Understanding%20Zeroconf%20Service%20Types).
    port: 48230, // Put your service port here.
  );
  static final BonsoirDiscovery _discovery = BonsoirDiscovery(
    type: service.type,
  );
  static final BonsoirBroadcast _broadcaster = BonsoirBroadcast(
    service: service,
  );

  static beginBroadcast() async {
    await _broadcaster.ready;
    await _broadcaster.start();
  }

  static stopBroadcast() async {
    await _broadcaster.stop();
  }

  static beginDiscovery() async {
    await _discovery.ready;

    // If you want to listen to the discovery :
    _discovery.eventStream!.listen((event) {
      // `eventStream` is not null as the discovery instance is "ready" !
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        print('Service found : ${event.service?.toJson()}');
        event.service!.resolve(
          _discovery.serviceResolver,
        ); // Should be called when the user wants to connect to this service.
      } else if (event.type ==
          BonsoirDiscoveryEventType.discoveryServiceResolved) {
        print('Service resolved : ${event.service?.toJson()}');
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        print('Service lost : ${event.service?.toJson()}');
      }
    });

    await _discovery.start();
  }

  static stopDiscovery() async {
    await _discovery.stop();
  }
}
