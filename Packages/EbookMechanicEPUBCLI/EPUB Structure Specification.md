## PDF Structure Specification



```mermaid
flowchart TB
    subgraph "Valid PDF Binary Structure"
        H["HEADER<br/>%PDF-1.x + newline<br/>(bytes 0-8+)"]
        B["BODY<br/>PDF Objects<br/>(1 obj...endobj)"]
        X["XREF TABLE<br/>xref<br/>byte offsets"]
        T["TRAILER<br/>trailer dict<br/>+ startxref<br/>+ %%EOF"]
        
        H --> B --> X --> T
    end
    
    style H fill:#FFE4B5,stroke:#333
    style T fill:#FFE4B5,stroke:#333
```

## Header Specification (PDF Reference 1.7)

```text
Byte Structure:
[0-4]:   %PDF-        (literal string, 5 bytes)
[5]:     Major version (ASCII digit, 1 byte)
[6]:     .            (period, 1 byte)  
[7]:     Minor version (ASCII digit, 1 byte)
[8+]:    \n or \r\n   (newline, 1-2 bytes)
[9+]:    Optional binary marker (%âãÏÓ or similar 4+ bytes with high bits)

```

