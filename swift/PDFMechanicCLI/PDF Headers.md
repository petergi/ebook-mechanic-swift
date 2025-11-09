## What's a PDF Header?

Every valid PDF file must start with a specific signature that looks like `%PDF-1.4` (or similar version number). This tells software "I'm a PDF file!"

Here's the structure:

mermaid

```mermaid
flowchart TB
    subgraph "Valid PDF File"
        A["%PDF-1.4<br/>(Header signature)"]
        B["PDF Objects<br/>(Content data)"]
        C["%%EOF<br/>(End marker)"]
        A --> B --> C
    end
    
    subgraph "Corrupted File"
        D["Extra bytes or<br/>wrong content"]
        E["Missing %PDF"]
        F["Content..."]
        D --> E --> F
    end
    
    style A fill:#90EE90
    style C fill:#90EE90
    style D fill:#FFB6C6
    style E fill:#FFB6C6
```

## Diagnostic Flow

mermaid

```mermaid
flowchart TD
    Start([PDF won't open:<br/>Missing PDF header])
    Check1{Can you open file<br/>in text editor?}
    Check2{Does it start<br/>with %PDF?}
    Check3{Is there junk<br/>before %PDF?}
    Check4{Is it actually<br/>a different format?}
    
    Fix1[Remove bytes<br/>before %PDF]
    Fix2[Convert file to<br/>proper format]
    Fix3[Try PDF<br/>repair tools]
    Fix4[Re-download or<br/>request new file]
    
    Start --> Check1
    Check1 -->|Yes| Check2
    Check1 -->|No/Binary| Check4
    Check2 -->|Yes| Check3
    Check2 -->|No| Check4
    Check3 -->|Yes| Fix1
    Check3 -->|No| Fix3
    Check4 -->|Wrong format| Fix2
    Check4 -->|Corrupted| Fix4
```

## Practical Fixes

**Method 1: Check and Clean the Header**

bash

```bash
# View first 20 bytes of file (Mac/Linux)
head -c 20 yourfile.pdf | od -c

# Should see: %PDF-1.x
```

If you see extra bytes before `%PDF`, you can remove them:

bash

```bash
# Find where %PDF starts, then extract from there
grep -abo "%PDF" yourfile.pdf  # Shows byte offset
dd if=yourfile.pdf of=fixed.pdf bs=1 skip=N  # N = offset number
```