# Protocol presets

The bundled YAML files describe header structure, not packet decoding. Variable data and options have illustrative widths. Use `bitgram init NAME` to create an editable copy.

| Name | Fixed bits | Definition source |
|---|---:|---|
| `tcp` | 160 | [RFC 9293 §3.1](https://www.rfc-editor.org/rfc/rfc9293.html#section-3.1); four reserved bits and eight flags |
| `udp` | 64 | [RFC 768](https://www.rfc-editor.org/rfc/rfc768.txt) |
| `ipv4` | 160 | [RFC 791 §3.1](https://www.rfc-editor.org/rfc/rfc791.html#section-3.1), with six-bit DSCP from [RFC 2474](https://www.rfc-editor.org/rfc/rfc2474.txt) and two-bit ECN from [RFC 3168](https://www.rfc-editor.org/rfc/rfc3168.txt) |
| `ipv6` | 320 | [RFC 8200 §3](https://www.rfc-editor.org/rfc/rfc8200.html#section-3); each address is 128 bits |
| `icmp` | 64 | [RFC 792](https://www.rfc-editor.org/rfc/rfc792.txt), Echo/Echo Reply format |
| `arp` | 224 | [RFC 826](https://www.rfc-editor.org/rfc/rfc826.txt), Ethernet/IPv4: 48-bit hardware addresses and 32-bit protocol addresses |

IPv4 Options and Padding share a display row (24 and 8 illustrative bits). IPv6 includes only the fixed header; extension headers and payload are separate structures. ARP address fields cross row boundaries and demonstrate relative bit-range labels.
