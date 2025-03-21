===========================================================
                OpenSSL Project Directory Structure
===========================================================

This document provides an overview of the directory structure of the OpenSSL project.
It is intended for developers and contributors who wish to understand where the
various components of the project reside.

-------------------------------
          Root-Level Files
-------------------------------
• ACKNOWLEDGEMENTS.md       – Credits and acknowledgements.
• AUTHORS.md               – List of contributors.
• CHANGES.md               – Summary of changes across releases.
• LICENSE.txt              – The OpenSSL license.
• NEWS.md                  – Release notes and project updates.
• INSTALL.md               – Installation and build instructions.
• VERSION.dat              – Contains version information.
• NOTES-ANDROID.md, NOTES-ANSI.md, NOTES-DJGPP.md, etc.
                           – Various notes and configuration files.

-------------------------------
         Major Directories
-------------------------------

1. apps/
   • Contains the source code for the command-line utilities and applications 
     (e.g., the main "openssl" binary).
   • Also includes demo applications, configuration files, and supporting libraries.

2. crypto/
   • Holds the core cryptographic library implementations.
   • Implements algorithms such as:
       – Symmetric ciphers (AES, DES, RC4, etc.)
       – Hash functions (SHA, MD5, etc.)
       – Public key algorithms (RSA, DSA, ECDSA, etc.)

3. demos/
   • Provides demonstration programs illustrating how to use OpenSSL’s API and libraries.

4. dev/
   • Contains files related to the development and release processes.
   • Includes guidelines, release notes formatting, and auxiliary release scripts.

5. doc/
   • Documentation sources for OpenSSL:
       – Manuals, reference guides, and design documents.
       – Diagrams and other assets used to build the final documentation.

6. engines/
   • Contains code for various cryptographic engines.
   • Often provides hardware acceleration or alternative implementations.

7. exporters/
   • Provides configuration files and templates for build systems and packaging tools
     (e.g., CMake files and pkg-config templates).

8. external/
   • Holds external dependencies and third-party libraries required by OpenSSL.
   • Includes Perl modules for text templating and similar tasks.

9. fuzz/
   • Contains fuzzing infrastructure and test cases to identify vulnerabilities.

10. gost-engine/
    • Provides an implementation of GOST cryptographic algorithms as an engine.

11. include/
    • Contains the public header files for OpenSSL.
    • These headers define the API and data structures for OpenSSL.

12. ms/
    • Build scripts and configuration files specific to Microsoft platforms (e.g., Windows).

13. pkcs11-provider/
    • Implements the PKCS#11 provider for interfacing with PKCS#11 modules.

14. providers/
    • Contains new provider modules implementing various cryptographic algorithms
      and services. Part of OpenSSL’s move toward a modular architecture.

15. pyca-cryptography/ and python-ecdsa/
    • Python bindings and implementations to facilitate the use of OpenSSL in Python projects.

16. ssl/
    • Contains the SSL/TLS protocol implementation:
       – The record layer and protocol state machines.
       – Handling of secure communications.

17. test/
    • Houses a comprehensive suite of tests including:
       – Unit tests, integration tests, regression tests, fuzzing tests, and
         tests against external vectors.

18. tlsfuzzer/ and tlslite-ng/
    • Additional tools and demos for testing TLS protocols and behaviors.

19. tools/
    • Provides various scripts and utilities for building, testing, and maintaining
      the project (e.g., build scripts, release tools, helper scripts).

20. util/
    • Contains miscellaneous scripts and tools for tasks such as code formatting,
      dependency management, and platform-specific adjustments.

21. VMS/
    • Includes files and scripts specific to the VMS operating system to support
      OpenSSL builds on VMS platforms.

22. wycheproof/
    • Contains test vectors and cases from the Wycheproof project, used to validate
      cryptographic implementations against known edge cases.

-------------------------------
         Directory Summary Tree
-------------------------------

  .
  ├── ACKNOWLEDGEMENTS.md
  ├── AUTHORS.md
  ├── CHANGES.md
  ├── LICENSE.txt
  ├── NEWS.md
  ├── INSTALL.md
  ├── VERSION.dat
  ├── apps/
  ├── crypto/
  ├── demos/
  ├── dev/
  ├── doc/
  ├── engines/
  ├── exporters/
  ├── external/
  ├── fuzz/
  ├── gost-engine/
  ├── include/
  ├── ms/
  ├── pkcs11-provider/
  ├── providers/
  ├── pyca-cryptography/
  ├── python-ecdsa/
  ├── ssl/
  ├── test/
  ├── tlsfuzzer/
  ├── tlslite-ng/
  ├── tools/
  ├── util/
  ├── VMS/
  └── wycheproof/

-------------------------------
            Conclusion
-------------------------------

The OpenSSL project is a comprehensive and modular codebase. Its structure clearly 
separates the cryptographic core, protocol implementations, testing infrastructure,
and build/documentation tools. This organization facilitates both maintenance and 
community contributions.

For a more detailed view, please refer to the complete repository tree in your local
checkout or through the online repository browser.

===========================================================

