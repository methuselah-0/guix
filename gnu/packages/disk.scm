;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2012, 2013 Nikita Karetnikov <nikita@karetnikov.org>
;;; Copyright © 2015 Mathieu Lirzin <mthl@gnu.org>
;;; Copyright © 2015 Mark H Weaver <mhw@netris.org>
;;; Copyright © 2016, 2018, 2019, 2020 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2016, 2019, 2020 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2016 Jan Nieuwenhuizen <janneke@gnu.org>
;;; Copyright © 2016 Roel Janssen <roel@gnu.org>
;;; Copyright © 2016, 2017 Marius Bakke <mbakke@fastmail.com>
;;; Copyright © 2017 Hartmut Goebel <h.goebel@crazy-compilers.com>
;;; Copyright © 2017 Stefan Reichör <stefan@xsteve.at>
;;; Copyright © 2018 Vasile Dumitrascu <va511e@yahoo.com>
;;; Copyright © 2018 Eric Bavier <bavier@member.fsf.org>
;;; Copyright © 2018 Rutger Helling <rhelling@mykolab.com>
;;; Copyright © 2018, 2019 Pierre Neidhardt <mail@ambrevar.xyz>
;;; Copyright © 2019 Leo Famulari <leo@famulari.name>
;;; Copyright © 2019 Pierre Langlois <pierre.langlois@gmx.com>
;;; Copyright © 2020 Pkill -9 <pkill9@runbox.com>
;;; Copyright © 2020 Vincent Legoll <vincent.legoll@gmail.com>
;;; Copyright © 2020 Raghav Gururajan <raghavgururajan@disroot.org>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages disk)
  #:use-module (gnu packages)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages c)
  #:use-module (gnu packages check)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages cryptsetup)
  #:use-module (gnu packages docbook)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages file-systems)
  #:use-module (gnu packages file)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages graphics)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages popt)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages readline)
  #:use-module (gnu packages samba)
  #:use-module (gnu packages sphinx)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages swig)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages textutils)
  #:use-module (gnu packages vim)
  #:use-module (gnu packages w3m)
  #:use-module (gnu packages web)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system glib-or-gtk)
  #:use-module (guix build-system go)
  #:use-module (guix build-system python)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system scons)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public udevil
  (package
    (name "udevil")
    (version "0.4.4")
    (source
     (origin
       (method git-fetch)
       (uri
        (git-reference
         (url "https://github.com/IgnorantGuru/udevil")
         (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0x9mjr9abvbxzfa9mrip5264iz1qxvsl01k3ybz95q4a7xl4jcb3"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags
       (list
        "--disable-systemd"
        (string-append "--sysconfdir="
                       (assoc-ref %outputs "out")
                       "/etc")
        ;; udevil expects these programs to be run with uid set as root.
        ;; user has to manually add these programs to setuid-programs.
        ;; mount and umount are default setuid-programs in guix system.
        "--with-mount-prog=/run/setuid-programs/mount"
        "--with-umount-prog=/run/setuid-programs/umount"
        "--with-losetup-prog=/run/setuid-programs/losetup"
        "--with-setfacl-prog=/run/setuid-programs/setfacl")
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'remove-root-reference
           (lambda _
             (substitute* "src/Makefile.in"
               (("-o root -g root") ""))
             #t))
         (add-after 'unpack 'patch-udevil-reference
           ;; udevil expects itself to be run with uid set as root.
           ;; devmon also expects udevil to be run with uid set as root.
           ;; user has to manually add udevil to setuid-programs.
           (lambda _
             (substitute* "src/udevil.c"
               (("/usr/bin/udevil") "/run/setuid-programs/udevil"))
             (substitute* "src/devmon"
               (("`which udevil 2>/dev/null`") "/run/setuid-programs/udevil"))
             #t)))))
    (native-inputs
     `(("intltool" ,intltool)
       ("pkg-config" ,pkg-config)))
    (inputs
     `(("cifs-utils" ,cifs-utils)
       ("curlftpfs" ,curlftpfs)
       ("eudev" ,eudev)
       ("fakeroot" ,fakeroot)
       ("glib" ,glib)
       ("sshfs" ,sshfs)))
    (synopsis "Device and file system manager")
    (description "udevil is a command line program that mounts and unmounts
removable devices without a password, shows device info, and monitors device
changes.  It can also mount ISO files, NFS, SMB, FTP, SSH and WebDAV URLs, and
tmpfs/ramfs filesystems.")
    (home-page "https://ignorantguru.github.io/udevil/")
    (license license:gpl3+)))

(define-public parted
  (package
    (name "parted")
    (version "3.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://gnu/parted/parted-"
                                  version ".tar.xz"))
              (sha256
               (base32
                "0i1xp367wpqw75b20c3jnism3dg3yqj4a7a22p2jb1h1hyyv9qjp"))))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'fix-locales-and-python
           (lambda* (#:key inputs #:allow-other-keys)
             (substitute* "tests/t0251-gpt-unicode.sh"
               (("C.UTF-8") "en_US.utf8")) ;not in Glibc locales
             (substitute* "tests/msdos-overlap"
               (("/usr/bin/python") (which "python")))
             #t)))))
    (inputs
     `(("lvm2" ,lvm2)
       ("readline" ,readline)
       ("util-linux" ,util-linux "lib")))
    (native-inputs
     `(("gettext" ,gettext-minimal)

       ;; For the tests.
       ("e2fsprogs" ,e2fsprogs)
       ("perl" ,perl)
       ("python" ,python-2)
       ("util-linux" ,util-linux)))
    (home-page "https://www.gnu.org/software/parted/")
    (synopsis "Disk partition editor")
    (description
     "GNU Parted is a package for creating and manipulating disk partition
tables.  It includes a library and command-line utility.")
    (license license:gpl3+)))

(define-public fdisk
  (package
    (name "fdisk")
    (version "2.0.0a1")
    (source
     (origin
      (method url-fetch)
      (uri (string-append "mirror://gnu/fdisk/gnufdisk-"
                          version ".tar.gz"))
      (sha256
       (base32
        "1d8za79kw8ihnp2br084rgyjv9whkwp7957rzw815i0izx6xhqy9"))))
    (build-system gnu-build-system)
    (inputs
     `(("gettext" ,gettext-minimal)
       ("guile" ,guile-1.8)
       ("util-linux" ,util-linux "lib")
       ("parted" ,parted)))
    ;; The build neglects to look for its own headers in its own tree.  A next
    ;; release should fix this, but may never come: GNU fdisk looks abandoned.
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'skip-broken-header-probes
           (lambda _
             (substitute* "backend/configure"
               (("gnufdisk-common.h .*") "\n"))
             #t)))
       #:make-flags (list (string-append "CPPFLAGS="
                                         " -I../common/include "
                                         " -I../debug/include "
                                         " -I../exception/include"))))
    (home-page "https://www.gnu.org/software/fdisk/")
    (synopsis "Low-level disk partitioning and formatting")
    (description
     "GNU fdisk provides a GNU version of the common disk partitioning tool
fdisk.  fdisk is used for the creation and manipulation of disk partition
tables, and it understands a variety of different formats.")
    (license license:gpl3+)))

(define-public gptfdisk
  (package
    (name "gptfdisk")
    (version "1.0.5")
    (source
     (origin
      (method url-fetch)
      (uri (string-append "mirror://sourceforge/gptfdisk/gptfdisk/"
                          version "/gptfdisk-" version ".tar.gz"))
      (sha256
       (base32 "0bybgp30pqxb6x5krxazkq4drca0gz4inxj89fpyr204rn3kjz8f"))))
    (build-system gnu-build-system)
    (inputs
     `(("gettext" ,gettext-minimal)
       ("ncurses" ,ncurses)
       ("popt" ,popt)
       ("util-linux" ,util-linux "lib"))) ;libuuid
    (arguments
     `(#:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'fix-include-directory
           (lambda _
             (substitute* "gptcurses.cc"
               (("ncursesw/ncurses.h") "ncurses.h"))
             #t))
         (delete 'configure)            ; no configure script
         (replace 'install
           ;; There's no ‘make install’ target.
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (man (string-append out "/share/man/man8")))
               (install-file "gdisk" bin)
               (install-file "sgdisk" bin)
               (install-file "cgdisk" bin)
               (install-file "fixparts" bin)
               (install-file "cgdisk.8" man)
               (install-file "fixparts.8" man)
               (install-file "gdisk.8" man)
               (install-file "sgdisk.8" man)))))))
    (home-page "https://www.rodsbooks.com/gdisk/")
    (synopsis "Low-level GPT disk partitioning and formatting")
    (description "GPT fdisk (aka gdisk) is a text-mode partitioning tool that
works on Globally Unique Identifier (@dfn{GUID}) Partition Table (@dfn{GPT})
disks, rather than on the older Master Boot Record (@dfn{MBR}) partition
scheme.")
    (license license:gpl2)))

(define-public ddrescue
  (package
    (name "ddrescue")
    (version "1.25")
    (source
     (origin
      (method url-fetch)
      (uri (string-append "mirror://gnu/ddrescue/ddrescue-"
                          version ".tar.lz"))
      (sha256
       (base32 "0qqh38izl5ppap9a5izf3hijh94k65s3zbfkczd4b7x04syqwlyf"))))
    (build-system gnu-build-system)
    (home-page "https://www.gnu.org/software/ddrescue/ddrescue.html")
    (synopsis "Data recovery utility")
    (native-inputs `(("lzip" ,lzip)))
    (description
     "GNU ddrescue is a fully automated data recovery tool.  It copies data
from one file to another, working to rescue data in case of read errors.  The
program also includes a tool for manipulating its log files, which are used
to recover data more efficiently by only reading the necessary blocks.")
    (license license:gpl3+)))

(define-public dosfstools
  (package
    (name "dosfstools")
    (version "4.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/" name "/" name
                           "/releases/download/v" version "/"
                           name "-" version ".tar.xz"))
       (sha256
        (base32
         "0wy13i3i4x2bw1hf5m4fd0myh61f9bcrs035fdlf6gyc1jksrcp6"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags (list "--enable-compat-symlinks")
       #:make-flags (list (string-append "PREFIX=" %output)
                          "CC=gcc")))
    (native-inputs
     `(("xxd" ,xxd))) ; for tests
    (home-page "https://github.com/dosfstools/dosfstools")
    (synopsis "Utilities for making and checking MS-DOS FAT file systems")
    (description
     "The dosfstools package includes the mkfs.fat and fsck.fat utilities,
which respectively make and check MS-DOS FAT file systems.")
    (license license:gpl3+)))

(define dosfstools/static
  (static-package
   (package (inherit dosfstools))))

(define-public fatfsck/static
  (package
    (name "fatfsck-static")
    (version (package-version dosfstools))
    (build-system trivial-build-system)
    (source #f)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let ((src (string-append (assoc-ref %build-inputs "dosfstools")
                                   "/sbin"))
               (exe "fsck.fat")
               (bin (string-append (assoc-ref %outputs "out") "/sbin")))
           (mkdir-p bin)
           (with-directory-excursion bin
             (copy-file (string-append src "/" exe) exe)
             (remove-store-references exe)
             (chmod exe #o555)
             ;; Add fsck.vfat symlink to match the Linux driver name.
             (symlink exe "fsck.vfat")
             #t)))))
    (inputs `(("dosfstools" ,dosfstools/static)))
    (home-page (package-home-page dosfstools))
    (synopsis "Statically linked fsck.fat from dosfstools")
    (description "This package provides a statically-linked @command{fsck.fat}
and a @command{fsck.vfat} compatibility symlink for use in an initrd.")
    (license (package-license dosfstools))))

(define-public sdparm
  (package
    (name "sdparm")
    (version "1.11")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "http://sg.danny.cz/sg/p/"
                           "sdparm-" version ".tar.xz"))
       (sha256
        (base32 "1nqjc4w2w47zavcbf5xmm53x1zbwgljaw1lpajcdi537cgy32fa8"))))
    (build-system gnu-build-system)
    (home-page "http://sg.danny.cz/sg/sdparm.html")
    (synopsis "Provide access to SCSI device parameters")
    (description
     "Sdparm reads and modifies SCSI device parameters.  These devices can be
SCSI disks, in which case the role of @command{sdparm} is similar to its
namesake: the @command{hdparm} utility originally designed for ATA disks.
However, @command{sdparm} can be used to access parameters on any device that
uses a SCSI command set.  Such devices include CD/DVD drives (irrespective of
transport), SCSI and ATAPI tape drives, and SCSI enclosures.  This utility can
also send commands associated with starting and stopping the media, loading
and unloading removable media and some other housekeeping functions.")
    (license license:bsd-3)))

(define-public idle3-tools
  (package
    (name "idle3-tools")
    (version "0.9.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://sourceforge/idle3-tools/idle3-tools-"
                           version ".tgz"))
       (sha256
        (base32
         "00ia7xq9yldxyl9gz0mr4xa568nav14p0fnv82f2rbbkg060cy4p"))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f ;no test suite
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))
       #:make-flags (list "CC=gcc"
                          (string-append "manprefix=")
                          (string-append "DESTDIR="
                                         (assoc-ref %outputs "out")))))
    (home-page "http://idle3-tools.sourceforge.net")
    (synopsis "Change or disable Western Digital hard drives' Idle3 timer")
    (description
     "Idle3-tools provides a utility to get, set, or disable the Idle3 timer
present in many Western Digital hard drives.  This timer is part of the
\"IntelliPark\" feature that stops the disk when not in use.  Unfortunately,
the default timer setting is not well suited to Linux or other *nix systems,
and can dramatically shorten the lifespan of the drive if left unchecked.")
    (license license:gpl3+)))

(define-public gparted
  (package
    (name "gparted")
    (version "1.1.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://sourceforge/gparted/gparted/gparted-"
                           version "/gparted-" version ".tar.gz"))
       (sha256
        (base32 "092rgwjh1825fal6v3yafq2wr0i61hh0a2n0j4296zn0zdx7pzp2"))))
    (build-system glib-or-gtk-build-system)
    (arguments
      ;; Tests require access to paths outside the build container, such
      ;; as '/dev/disk/by-id'
     `(#:tests? #f))
    (inputs
     `(("util-linux" ,util-linux "lib")
       ("parted" ,parted)
       ("glib" ,glib)
       ("gtkmm" ,gtkmm)
       ("libxml2" ,libxml2)))
    (native-inputs
     `(("intltool" ,intltool)
       ("itstool" ,itstool)
       ("lvm2" ,lvm2) ; for tests
       ("yelp-tools" ,yelp-tools)
       ("pkg-config" ,pkg-config)))
    (home-page "https://gparted.org/")
    (synopsis "Partition editor to graphically manage disk partitions")
    (description "GParted is a GNOME partition editor for creating,
reorganizing, and deleting disk partitions.  It uses libparted from the parted
project to detect and manipulate partition tables.  Optional file system tools
permit managing file systems not included in libparted.")
    ;; The home page says GPLv2, but the source code says GPLv2+.
    (license license:gpl2+)))

(define-public pydf
  (package
    (name "pydf")
    (version "12")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "pydf" version))
       (sha256
        (base32
         "0f8ly8xyp93i2hm9c0qjqd4y86nz73axw2f09z01mszwmg1sfivz"))))
  (build-system python-build-system)
  (home-page "http://kassiopeia.juls.savba.sk/~garabik/software/pydf/")
  (synopsis "Colourised @command{df} clone")
  (description "All-singing, all-dancing, fully colourised @command{df} clone
written in Python.  It displays the amount of disk space available on the
mounted file systems, using different colours for different types of file
systems.  Output format is completely customizable.")
  (license license:public-domain)))

(define-public f3
  (package
    (name "f3")
    (version "7.2")
    (source
     (origin
      (method git-fetch)
      (uri (git-reference
            (url "https://github.com/AltraMayor/f3")
            (commit (string-append "v" version))))
      (file-name (git-file-name name version))
      (sha256
       (base32 "1iwdg0r4wkgc8rynmw1qcqz62l0ldgc8lrazq33msxnk5a818jgy"))))
    (build-system gnu-build-system)
    (arguments
     '(#:tests? #f                      ; no check target
       #:make-flags (list "CC=gcc"
                          (string-append "PREFIX=" %output))
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)            ; no configure script
         (add-after 'build 'build-extra
           (lambda* (#:key make-flags #:allow-other-keys)
             (apply invoke "make" "extra" make-flags)))
         (add-after 'build 'install-extra
           (lambda* (#:key make-flags #:allow-other-keys)
             (apply invoke "make" "install-extra" make-flags))))))
    (inputs
     `(("eudev" ,eudev)
       ("parted" ,parted)))
    (home-page "http://oss.digirati.com.br/f3/")
    (synopsis "Test real capacity of flash memory cards and such.")
    (description "F3 (Fight Flash Fraud or Fight Fake Flash) tests the full
capacity of a flash card (flash drive, flash disk, pendrive).  F3 writes to
the card and then checks if can read it.  It will assure you haven't been sold
a card with a smaller capacity than stated.")
    (license license:gpl3+)))

(define-public python-parted
  (package
    (name "python-parted")
    (version "3.11.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/dcantrell/pyparted")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0r6916n3w4vldxrq30a3z2iagvxgly4vfmlidjm65vwqnyv17bvn"))))
    (build-system python-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (delete 'check)
         (add-after 'install 'check
           (lambda* (#:key outputs inputs #:allow-other-keys)
             (add-installed-pythonpath inputs outputs)
             ;; See <https://github.com/dcantrell/pyparted/issues/47>.
             (substitute* "tests/test__ped_ped.py"
               (("\"/tmp/temp-device-\"") "self.path"))
             (invoke "python" "-m" "unittest" "discover" "-v")
             #t)))))
    (native-inputs
     `(("e2fsprogs" ,e2fsprogs)
       ("pkg-config" ,pkg-config)))
    (propagated-inputs
     `(("python-six" ,python-six)))
    (inputs
     `(("parted" ,parted)))
    (home-page "https://github.com/dcantrell/pyparted")
    (synopsis "Parted bindings for Python")
    (description "This package provides @code{parted} bindings for Python.")
    (license license:gpl2+)))

(define-public python2-parted
  (package-with-python2 python-parted))

(define-public duperemove
  (package
    (name "duperemove")
    (version "0.11.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/markfasheh/duperemove")
             (commit (string-append "v" version))))
       (sha256
        (base32 "1scz76pvpljvrpfn176125xwaqwyy4pirlm11sc9spb2hyzknw2z"))
       (file-name (git-file-name name version))))
    (build-system gnu-build-system)
    (native-inputs
     `(("pkg-config" ,pkg-config)))
    (inputs
     `(("glib" ,glib)
       ("sqlite" ,sqlite)))
    (arguments
     `(#:tests? #f                      ; no test suite
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))           ; no configure script
       #:make-flags (list (string-append "PREFIX=" %output)
                          "CC=gcc")))
    (home-page "https://github.com/markfasheh/duperemove")
    (synopsis "Tools for de-duplicating file system data")
    (description "Duperemove is a simple tool for finding duplicated extents
and submitting them for deduplication.  When given a list of files it will
hash their contents on a block by block basis and compare those hashes to each
other, finding and categorizing blocks that match each other.  When given the
@option{-d} option, duperemove will submit those extents for deduplication
using the Linux kernel extent-same @code{ioctl}.

Duperemove can store the hashes it computes in a @dfn{hash file}.  If given an
existing hash file, duperemove will only compute hashes for those files which
have changed since the last run.  Thus you can run duperemove repeatedly on
your data as it changes, without having to re-checksum unchanged data.

Duperemove can also take input from the @command{fdupes} program.")
    (license license:gpl2)))

(define-public ranger
  (package
    (name "ranger")
    (version "1.9.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://ranger.github.io/"
                                  "ranger-" version ".tar.gz"))
              (sha256
               (base32
                "0lfjrpv3z4h0knd3v94fijrw2zjba51mrp3mjqx2c98wr428l26f"))))
    (build-system python-build-system)
    (inputs
     `(("w3m" ,w3m)))
    (native-inputs
     `(("which" ,which)

       ;; For tests.
       ("python-pytest" ,python-pytest)))
    (arguments
     '( ;; The 'test' target runs developer tools like pylint, which fail.
       #:test-target "test_pytest"
       #:phases
       (modify-phases %standard-phases
         (add-after 'configure 'wrap-program
           ;; Tell 'ranger' where 'w3mimgdisplay' is.
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((out  (assoc-ref outputs "out"))
                    (ranger (string-append out "/bin/ranger"))
                    (w3m (assoc-ref inputs "w3m"))
                    (w3mimgdisplay (string-append w3m
                                   "/libexec/w3m/w3mimgdisplay")))
               (wrap-program ranger
                 `("W3MIMGDISPLAY_PATH" ":" prefix (,w3mimgdisplay)))
               #t)))
         (replace 'check
           ;; The default check phase simply prints 'Ran 0 tests in 0.000s'.
           (lambda* (#:key test-target #:allow-other-keys)
             (invoke "make" test-target))))))
    (home-page "https://ranger.github.io/")
    (synopsis "Console file manager")
    (description "ranger is a console file manager with Vi key bindings.  It
provides a minimalistic and nice curses interface with a view on the directory
hierarchy.  It ships with @code{rifle}, a file launcher that is good at
automatically finding out which program to use for what file type.")
    (license license:gpl3)))

(define-public volume-key
  (package
    (name "volume-key")
    (version "0.3.12")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://releases.pagure.org/volume_key/volume_key-"
                                  version ".tar.xz"))
              (sha256
               (base32
                "16rhfz6sjwxlmss1plb2wv2i3jq6wza02rmz1d2jrlnsq67p98vc"))))
    (build-system gnu-build-system)
    (native-inputs
     `(("pkg-config" ,pkg-config)
       ("swig" ,swig)
       ("python" ,python-3)))           ; used to generate the Python bindings
    (inputs
     `(("cryptsetup" ,cryptsetup)
       ("nss" ,nss)
       ("libblkid" ,util-linux "lib")
       ("lvm2" ,lvm2)                   ; for "-ldevmapper"
       ("glib" ,glib)
       ("gpgme" ,gpgme)))
    (arguments
     `(#:tests? #f ; not sure how tests are supposed to pass, even when run manually
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-python.h-path
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((python (assoc-ref inputs "python")))
               (substitute* "Makefile.in"
                 (("/usr/include/python") (string-append python "/include/python")))
               #t))))))
    (home-page "https://pagure.io/volume_key")
    (synopsis "Manipulate storage volume encryption keys")
    (description
     "This package provides a library for manipulating storage volume
encryption keys and storing them separately from volumes to handle forgotten
passphrases.")
    (license license:gpl2)))

(define-public ndctl
  (package
    (name "ndctl")
    (version "68")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/pmem/ndctl")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0xmim7z4qp6x2ggndnbwd940c73pa1qlf3hxyn3qh5pyr69nh9y8"))))
    (build-system gnu-build-system)
    (native-inputs
     `(("asciidoc" ,asciidoc)
       ("automake" ,automake)
       ("autoconf" ,autoconf)
       ("bash-completion" ,bash-completion)
       ("docbook-xsl" ,docbook-xsl)
       ("libtool" ,libtool)
       ("libxml2" ,libxml2)
       ("pkg-config" ,pkg-config)
       ("xmlto" ,xmlto)
       ;; Required for offline docbook generation.
       ("which" ,which)))
    (inputs
     `(("eudev" ,eudev)
       ("json-c" ,json-c)
       ("keyutils" ,keyutils)
       ("kmod" ,kmod)
       ("util-linux" ,util-linux "lib")))
    (arguments
     `(#:configure-flags
       (list "--disable-asciidoctor"    ; use docbook-xsl instead
             "--without-systemd")
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-FHS-file-names
           (lambda _
             (substitute* "git-version-gen"
               (("/bin/sh") (which "sh")))
             (substitute* "git-version"
               (("/bin/bash") (which "bash")))
             #t)))
       #:make-flags
       (let ((out (assoc-ref %outputs "out")))
         (list (string-append "BASH_COMPLETION_DIR=" out
                              "/share/bash-completion/completions")))))
    (home-page "https://github.com/pmem/ndctl")
    (synopsis "Manage the non-volatile memory device sub-system in the Linux kernel")
    (description
     "This package provides a utility library for managing the
libnvdimm (non-volatile memory device) sub-system in the Linux kernel.")
    ;; COPYING says LGPL2.1, but many source files are GPL2 so that's
    ;; the effective license.  Note that some files under ccan/ are
    ;; covered by BSD-3 or public domain, see the individual folders.
    (license license:gpl2)))

(define-public dmraid
  (package
    (name "dmraid")
    (version "1.0.0.rc16-3")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://people.redhat.com/~heinzm/sw/dmraid/src/dmraid-"
                                  version ".tar.bz2"))
              (sha256
               (base32
                "1n7vsqvh7y6yvil682q129d21yhb0cmvd5fvsbkza7ypd78inhlk"))))
    (build-system gnu-build-system)
    (inputs `(("lvm2" ,lvm2)))
    (native-inputs `(("which" ,which)))
    (arguments
     `(#:tests? #f                      ; No tests.
       ;; Prevent a race condition where some target would attempt to link
       ;; libdmraid.so before it had been built as reported in
       ;; <https://bugs.gnu.org/31999#187>.
       #:parallel-build? #f
       #:phases (modify-phases %standard-phases
                  (add-before 'configure 'change-directory
                    (lambda _
                      (chdir (string-append ,version "/dmraid"))
                      (substitute* "make.tmpl.in"
                        (("/bin/sh") (which "sh")))
                      #t)))
       #:configure-flags (list ;; Make sure programs such as 'dmevent_tool' can
                               ;; find libdmraid.so.
                               (string-append "LDFLAGS=-Wl,-rpath="
                                              (assoc-ref %outputs "out")
                                              "/lib"))))
    (home-page "https://people.redhat.com/~heinzm/sw/dmraid/")
    (synopsis "Device mapper RAID interface")
    (description
     "This software supports RAID device discovery, RAID set activation, creation,
removal, rebuild and display of properties for ATARAID/DDF1 metadata.

@command{dmraid} uses @file{libdevmapper} and the device-mapper kernel runtime
to create devices with respective mappings for the ATARAID sets discovered.")
    (license license:gpl2+)))

(define-public libblockdev
  (package
    (name "libblockdev")
    (version "2.24")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/storaged-project/"
                                  "libblockdev/releases/download/"
                                  version "-1/libblockdev-" version ".tar.gz"))
              (sha256
               (base32
                "0wq7624pnprvfzrf39bq1cybd9lqwawbdg5bm0cchlpgvdq7q86w"))))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-configuration-directory
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
              (substitute* "src/lib/blockdev.c"
               (("/etc/libblockdev/conf.d/" path) (string-append out path)))))))))
    (native-inputs
     `(("gobject-introspection" ,gobject-introspection)
       ("pkg-config" ,pkg-config)
       ("python" ,python-wrapper)
       ("util-linux" ,util-linux)))
    (inputs
     `(("btrfs-progs" ,btrfs-progs)
       ("cryptsetup" ,cryptsetup)
       ("dosfstools" ,dosfstools)
       ("dmraid" ,dmraid)
       ("eudev" ,eudev)
       ("glib" ,glib)
       ("kmod" ,kmod)
       ("libbytesize" ,libbytesize)
       ("libyaml" ,libyaml)
       ("lvm2" ,lvm2)
       ("mdadm" ,mdadm)
       ("ndctl" ,ndctl)
       ("nss" ,nss)
       ("parted" ,parted)
       ("volume-key" ,volume-key)
       ;; ("xfsprogs" ,xfsprogs) ; TODO: Package?
       ))
    (home-page "https://github.com/storaged-project/libblockdev")
    (synopsis "Library for manipulating block devices")
    (description
     "libblockdev is a C library supporting GObject introspection for
manipulation of block devices.  It has a plugin-based architecture where each
technology (like LVM, Btrfs, MD RAID, Swap...) is implemented in a separate
plugin, possibly with multiple implementations (e.g. using LVM CLI or the new
LVM D-Bus API).")
    (license license:lgpl2.1+)))

(define-public rmlint
  (package
    (name "rmlint")
    (version "2.10.1")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/sahib/rmlint")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "15xfkcw1bkfyf3z8kl23k3rlv702m0h7ghqxvhniynvlwbgh6j2x"))))
    (build-system scons-build-system)
    (arguments
     `(#:scons ,scons-python2
       #:scons-flags (list (string-append "--prefix=" %output)
                           (string-append "--actual-prefix=" %output))
       #:tests? #f                      ; No tests?
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'scons-propagate-environment
           (lambda* (#:key inputs #:allow-other-keys)
             ;; TODO: `rmlint --gui` fails with
             ;; "Failed to load shredder: No module named 'shredder'".
             ;; The GUI might also need extra dependencies, such as
             ;; python-gobject, python-cairo, dconf, librsvg, gtksourceview3.
             (substitute* "lib/cmdline.c"
               (("const char \\*commands\\[\\] = \\{\"python3\", \"python\", NULL\\};")
                (string-append
                 "const char *commands[] = {\""
                 (assoc-ref inputs "python") "/bin/python"
                 "\", \"python\", NULL};")))
             ;; By design, SCons does not, by default, propagate
             ;; environment variables to subprocesses.  See:
             ;; <http://comments.gmane.org/gmane.linux.distributions.nixos/4969>
             ;; Here, we modify the SConstruct file to arrange for
             ;; environment variables to be propagated.
             (substitute* "SConstruct"
               (("^env = Environment\\(.*\\)" all)
                (string-append
                 all
                 "\nenv['ENV']=os.environ"))))))))
    (native-inputs
     `(("pkg-config" ,pkg-config)
       ("glib:bin" ,glib "bin")
       ("python-sphinx" ,python-sphinx)))
    (inputs
     `(("python" ,python-wrapper)
       ("glib" ,glib)
       ("libelf" ,libelf)
       ("elfutils" ,elfutils)
       ("json-glib" ,json-glib)
       ("libblkid" ,util-linux "lib")))
    (home-page "https://rmlint.rtfd.org")
    (synopsis "Remove duplicates and other lint from the file system")
    (description "@command{rmlint} finds space waste and other broken things
on your file system and offers to remove it.  @command{rmlint} can find:

@itemize
@item duplicate files and duplicate directories,
@item non-stripped binaries (i.e. binaries with debug symbols),
@item broken symbolic links,
@item empty files and directories,
@item files with broken user and/or group ID.
@end itemize\n")
    (license license:gpl3+)))

(define-public lf
  (package
    (name "lf")
    (version "13")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/gokcehan/lf")
                    (commit (string-append "r" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "1ld3q75v8rvp169w5p85z1vznqs9bhck6bm2f6fykxx16hmpb6ga"))))
    (build-system go-build-system)
    (native-inputs
     `(("go-github.com-mattn-go-runewidth" ,go-github.com-mattn-go-runewidth)
       ("go-github.com-nsf-termbox-go" ,go-github.com-nsf-termbox-go)))
    (arguments
     `(#:import-path "github.com/gokcehan/lf"))
    (home-page "https://github.com/gokcehan/lf")
    (synopsis "Console file browser similar to Ranger")
    (description "lf (as in \"list files\") is a terminal file manager
written in Go.  It is heavily inspired by ranger with some missing and
extra features.  Some of the missing features are deliberately omitted
since they are better handled by external tools.")
    (license license:expat)))

(define-public xfe
  (package
    (name "xfe")
    (version "1.43.2")
    (source
     (origin
       (method url-fetch)
       (uri
        (string-append "mirror://sourceforge/xfe/xfe/" version "/"
                       "xfe-" version ".tar.gz"))
       (sha256
        (base32 "1fl51k5jm2vrfc2g66agbikzirmp0yb0lqhmsssixfb4mky3hpzs"))))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'patch-bin-dirs
           (lambda* (#:key inputs #:allow-other-keys)
             (let* ((bash (assoc-ref inputs "bash"))
                    (coreutils (assoc-ref inputs "coreutils"))
                    (findutils (assoc-ref inputs "findutils"))
                    (file-prog (assoc-ref inputs "file")))
               (with-directory-excursion "src"
                 (substitute* '("FilePanel.cpp" "help.h" "SearchPanel.cpp"
                                "startupnotification.cpp" "xfeutils.cpp"
                                "../st/config.h")
                   (("/bin/sh" file) (string-append bash file))
                   (("/bin/ls" file) (string-append coreutils file))
                   (("/usr(/bin/du)" _ file) (string-append coreutils file))
                   (("/usr(/bin/sort)" _ file) (string-append coreutils file))
                   (("/usr(/bin/cut)" _ file) (string-append coreutils file))
                   (("/usr(/bin/xargs)" _ file) (string-append findutils file))
                   (("/usr(/bin/file)" _ file) (string-append file-prog file))))
               #t)))
         (add-after 'unpack 'patch-share-dirs
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (share (string-append out "/share"))
                    (xfe (string-append share "/xfe")))
               (with-directory-excursion "src"
                 (substitute* '("foxhacks.cpp" "help.h" "xfedefs.h"
                                "XFileExplorer.cpp")
                   (("/(usr|opt)(/local)?/share") share)
                   (("~/.config/xfe") xfe)))
               #t))))))
    (native-inputs
     `(("intltool" ,intltool)
       ("pkg-config" ,pkg-config)))
    (inputs
     `(("bash" ,bash)
       ("coreutils" ,coreutils)
       ("file" ,file)
       ("findutils" ,findutils)
       ("fox" ,fox)
       ("freetype" ,freetype)
       ("x11" ,libx11)
       ("xcb" ,libxcb)
       ("xcb-util" ,xcb-util)
       ("xft" ,libxft)
       ("xrandr" ,libxrandr)))
    (synopsis "File Manager for X-Based Graphical Systems")
    (description "XFE (X File Explorer) is a file manager for X.  It is based on
the popular but discontinued, X Win Commander.  It aims to be the file manager
of choice for all light thinking Unix addicts!")
    (home-page "http://roland65.free.fr/xfe/")
    (license license:gpl2+)))
