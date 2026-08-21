accuracy|behavioral|c-001|answered|The indexer rebuilds the search index on every upload.
accuracy|signature|c-002|confirmed|src/loader.js:17
accuracy|self-citation|c-003|confirmed|CONTRIBUTING.md:24
effectiveness|question|q1|answered|This service turns uploaded documents into a searchable index.
effectiveness|question|q2|answered|Run make setup and then make check to confirm the install.
effectiveness|question|q3|answered|src/loader holds ingestion and src/indexer holds the search index.
effectiveness|question|q4|answered|Never edit files under generated/ by hand.
effectiveness|question|q5|answered|Add a document format by registering it in src/formats/registry.js.
RESULT|accuracy|PASS|dispatched=3|spot-checked=2/2|unverified-other=1
RESULT|effectiveness|PASS|answered=5/5
OVERALL|PASS
