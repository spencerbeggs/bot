# Convention

* [Place BATS tests by how host-specific the claim is](bats-test-placement.md) - Host-agnostic claims go in plugins/\_\_test\_\_/; host-specific claims go in the owning target workspace's \_\_test\_\_/, and bats collects both with no registration.
* [Write to the narrowest layer, and fetch docs before authoring](narrowest-layer-fetch-first.md) - Author each plugin component at the narrowest host layer that carries the capability, and settle claims from your layer's reference, then the stamped URL, never from memory.
