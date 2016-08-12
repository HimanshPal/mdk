quark 1.0;

package datawire_mdk_synapse 1.0.0;

use discovery-3.0.q;
use mdk_runtime.q;

import mdk_discovery;
import mdk_runtime;
import actors.core;
import mdk_runtime.files;

namespace mdk_synapse {
    @doc("""
    AirBnB Synapse discovery source.

    Reads Synapse-generated files (https://github.com/airbnb/synapse#file) and
    generates discovery events.

    Usage:

        m = mdk.init()
        m.registerDiscoverySource(Synapse('/path/to/synapse/files'))
        m.start()

    All resulting Node instances will have version '1.0' hardcoded, and an
    address of the form '<host>:<port>'.

    The original object from Synpase will be attached as the Node's properties.
    """)
    class Synapse extends DiscoverySourceFactory {
        String _directory_path;

        Synapse(String directory_path) {
            self._directory_path = directory_path;
        }

        DiscoverySource create(Actor subscriber, MDKRuntime runtime) {
            return new _SynapseSource(subscriber, self._directory_path, runtime);
        }
    }

    @doc("Implementation of the Synapse discovery source.")
    class _SynapseSource extends DiscoverySource {
        Actor subscriber;
        String directory_path;
        FileActor files;
        MessageDispatcher dispatcher;

        _SynapseSource(Actor subscriber, String directory_path, MDKRuntime runtime) {
            self.subscriber = subscriber;
            self.directory_path = directory_path;
            self.files = runtime.getFileService();
        }

        void onStart(MessageDispatcher dispatcher) {
            self.dispatcher = dispatcher;
            self.dispatcher.tell(self, new SubscribeChanges(self.directory_path),
                                 self.files);
        }

        @doc("Convert '/path/to/service_name.json' to 'service_name'.")
        String _pathToServiceName(String filename) {
            // Filename will be of form /path/to/service_name.json:
            List<String> parts = filename.split("/");
            String service = parts[parts.size() - 1];
            // String ".json" from end:
            return service.substring(0, service.size() - 5);
        }

        @doc("Send an appropriate update to the subscriber for this DiscoverySource.")
        void _update(String service, List<Node> nodes) {
            self.dispatcher.tell(self, new ReplaceCluster(service, nodes),
                                 self.subscriber);
        }

        void onMessage(Actor origin, Object message) {
            String typeId = message.getClass().id;
            if (typeId == "mdk_runtime.files.FileContents") {
                // A file was modified or created, read the JSON and convert it
                // to Node objects.
                FileContents contents = ?message;
                String service = self._pathToServiceName(contents.path);
                JSONObject json = contents.contents.parseJSON();
                List<Node> nodes = [];
                int idx = 0;
                while (idx < json.size()) {
                    JSONObject entry = json.getListItem(idx);
                    Node node = new Node();
                    node.service = service;
                    node.version = "1.0";
                    String host = entry.getObjectItem("host").getString();
                    node.address = (host + ":" +
                                    entry.getObjectItem("port").getNumber().round().toString());
                    nodes.add(node);
                    idx = idx + 1;
                }
                self._update(service, nodes);
                return;
            }
        }
    }
}
