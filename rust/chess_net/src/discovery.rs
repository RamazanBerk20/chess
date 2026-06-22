//! mDNS advertise/browse for `_chess._tcp` hosts.

use std::sync::mpsc::Receiver;

use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};

use crate::protocol::SERVICE_TYPE;
use crate::NetError;

/// Keeps a registered service alive; unregisters on drop.
pub struct Advertiser {
    daemon: ServiceDaemon,
    fullname: String,
}

/// Advertise a host on the LAN. `port` is the TCP port peers connect to.
pub fn advertise(
    name: &str,
    port: u16,
    base_minutes: u32,
    increment_seconds: u32,
) -> Result<Advertiser, NetError> {
    let daemon = ServiceDaemon::new()?;
    let instance = sanitize(name);
    let host = format!("{instance}.local.");
    let tc = format!("{base_minutes}+{increment_seconds}");
    let props: [(&str, &str); 3] = [("name", name), ("tc", &tc), ("ver", "1")];

    let info = ServiceInfo::new(SERVICE_TYPE, &instance, &host, "", port, &props[..])?
        .enable_addr_auto();
    let fullname = info.get_fullname().to_string();
    daemon.register(info)?;
    Ok(Advertiser { daemon, fullname })
}

impl Drop for Advertiser {
    fn drop(&mut self) {
        let _ = self.daemon.unregister(&self.fullname);
        let _ = self.daemon.shutdown();
    }
}

/// A discovered host on the LAN.
#[derive(Clone, Debug)]
pub struct DiscoveredHost {
    pub name: String,
    pub addr: String, // "ip:port"
    pub time_control: String,
}

/// Keeps a browse session alive; stops on drop.
pub struct Browser {
    daemon: ServiceDaemon,
}

impl Drop for Browser {
    fn drop(&mut self) {
        let _ = self.daemon.stop_browse(SERVICE_TYPE);
        let _ = self.daemon.shutdown();
    }
}

/// Browse for chess hosts. Returns a handle (drop to stop) and a channel of
/// resolved hosts. A background thread translates mDNS events.
pub fn browse() -> Result<(Browser, Receiver<DiscoveredHost>), NetError> {
    let daemon = ServiceDaemon::new()?;
    let events = daemon.browse(SERVICE_TYPE)?;
    let (tx, rx) = std::sync::mpsc::channel();

    std::thread::spawn(move || {
        while let Ok(event) = events.recv() {
            if let ServiceEvent::ServiceResolved(info) = event {
                let Some(ip) = info.get_addresses().iter().next() else {
                    continue;
                };
                let host = DiscoveredHost {
                    name: info
                        .get_property_val_str("name")
                        .unwrap_or("Chess host")
                        .to_string(),
                    addr: format!("{ip}:{}", info.get_port()),
                    time_control: info
                        .get_property_val_str("tc")
                        .unwrap_or("?")
                        .to_string(),
                };
                if tx.send(host).is_err() {
                    break; // consumer dropped
                }
            }
        }
    });

    Ok((Browser { daemon }, rx))
}

/// mDNS instance names can't contain dots/spaces; replace them.
fn sanitize(name: &str) -> String {
    let cleaned: String = name
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect();
    if cleaned.is_empty() {
        "chess".to_string()
    } else {
        cleaned
    }
}
