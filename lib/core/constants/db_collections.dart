const accountCollection = 'players';
const proxiesCollection =
    'proxies'; // Legacy collection - keeping for backwards compatibility

// New proxy management collections
const proxySlotsCollection = 'proxy_slots';
const proxyIpAddressesCollection = 'proxy_ip_addresses';
// IP history is tracked via isActive flag in proxy_ip_addresses
// Active IPs have isActive: true, historical IPs have isActive: false

// Settings collection for storing integrations and preferences
const settingsCollection = 'settings';
