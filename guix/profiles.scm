;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2013, 2014 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2013 Nikita Karetnikov <nikita@karetnikov.org>
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

(define-module (guix profiles)
  #:use-module (guix utils)
  #:use-module (guix records)
  #:use-module (guix derivations)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 ftw)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-19)
  #:use-module (srfi srfi-26)
  #:export (manifest make-manifest
            manifest?
            manifest-entries

            <manifest-entry>              ; FIXME: eventually make it internal
            manifest-entry
            manifest-entry?
            manifest-entry-name
            manifest-entry-version
            manifest-entry-output
            manifest-entry-item
            manifest-entry-dependencies

            manifest-pattern
            manifest-pattern?

            manifest-remove
            manifest-add
            manifest-installed?
            manifest-matching-entries

            profile-manifest
            package->manifest-entry
            profile-derivation
            generation-number
            generation-numbers
            previous-generation-number
            generation-time
            generation-file-name))

;;; Commentary:
;;;
;;; Tools to create and manipulate profiles---i.e., the representation of a
;;; set of installed packages.
;;;
;;; Code:


;;;
;;; Manifests.
;;;

(define-record-type <manifest>
  (manifest entries)
  manifest?
  (entries manifest-entries))                     ; list of <manifest-entry>

;; Convenient alias, to avoid name clashes.
(define make-manifest manifest)

(define-record-type* <manifest-entry> manifest-entry
  make-manifest-entry
  manifest-entry?
  (name         manifest-entry-name)              ; string
  (version      manifest-entry-version)           ; string
  (output       manifest-entry-output             ; string
                (default "out"))
  (item         manifest-entry-item)              ; package | store path
  (dependencies manifest-entry-dependencies       ; (store path | package)*
                (default '())))

(define-record-type* <manifest-pattern> manifest-pattern
  make-manifest-pattern
  manifest-pattern?
  (name         manifest-pattern-name)            ; string
  (version      manifest-pattern-version          ; string | #f
                (default #f))
  (output       manifest-pattern-output           ; string | #f
                (default "out")))

(define (profile-manifest profile)
  "Return the PROFILE's manifest."
  (let ((file (string-append profile "/manifest")))
    (if (file-exists? file)
        (call-with-input-file file read-manifest)
        (manifest '()))))

(define* (package->manifest-entry package #:optional output)
  "Return a manifest entry for the OUTPUT of package PACKAGE.  When OUTPUT is
omitted or #f, use the first output of PACKAGE."
  (let ((deps (map (match-lambda
                    ((label package)
                     `(,package "out"))
                    ((label package output)
                     `(,package ,output)))
                   (package-transitive-propagated-inputs package))))
    (manifest-entry
     (name (package-name package))
     (version (package-version package))
     (output (or output (car (package-outputs package))))
     (item package)
     (dependencies (delete-duplicates deps)))))

(define (manifest->gexp manifest)
  "Return a representation of MANIFEST as a gexp."
  (define (entry->gexp entry)
    (match entry
      (($ <manifest-entry> name version output (? string? path) (deps ...))
       #~(#$name #$version #$output #$path #$deps))
      (($ <manifest-entry> name version output (? package? package) (deps ...))
       #~(#$name #$version #$output
                 (ungexp package (or output "out")) #$deps))))

  (match manifest
    (($ <manifest> (entries ...))
     #~(manifest (version 1)
                 (packages #$(map entry->gexp entries))))))

(define (sexp->manifest sexp)
  "Parse SEXP as a manifest."
  (match sexp
    (('manifest ('version 0)
                ('packages ((name version output path) ...)))
     (manifest
      (map (lambda (name version output path)
             (manifest-entry
              (name name)
              (version version)
              (output output)
              (item path)))
           name version output path)))

    ;; Version 1 adds a list of propagated inputs to the
    ;; name/version/output/path tuples.
    (('manifest ('version 1)
                ('packages ((name version output path deps) ...)))
     (manifest
      (map (lambda (name version output path deps)
             (manifest-entry
              (name name)
              (version version)
              (output output)
              (item path)
              (dependencies deps)))
           name version output path deps)))

    (_
     (error "unsupported manifest format" manifest))))

(define (read-manifest port)
  "Return the packages listed in MANIFEST."
  (sexp->manifest (read port)))

(define (entry-predicate pattern)
  "Return a procedure that returns #t when passed a manifest entry that
matches NAME/OUTPUT/VERSION.  OUTPUT and VERSION may be #f, in which case they
are ignored."
  (match pattern
    (($ <manifest-pattern> name version output)
     (match-lambda
      (($ <manifest-entry> entry-name entry-version entry-output)
       (and (string=? entry-name name)
            (or (not entry-output) (not output)
                (string=? entry-output output))
            (or (not version)
                (string=? entry-version version))))))))

(define (manifest-remove manifest patterns)
  "Remove entries for each of PATTERNS from MANIFEST.  Each item in PATTERNS
must be a manifest-pattern."
  (define (remove-entry pattern lst)
    (remove (entry-predicate pattern) lst))

  (make-manifest (fold remove-entry
                       (manifest-entries manifest)
                       patterns)))

(define (manifest-add manifest entries)
  "Add a list of manifest ENTRIES to MANIFEST and return new manifest.
Remove MANIFEST entries that have the same name and output as ENTRIES."
  (define (same-entry? entry name output)
    (match entry
      (($ <manifest-entry> entry-name _ entry-output _ ...)
       (and (equal? name entry-name)
            (equal? output entry-output)))))

  (make-manifest
   (append entries
           (fold (lambda (entry result)
                   (match entry
                     (($ <manifest-entry> name _ out _ ...)
                      (filter (negate (cut same-entry? <> name out))
                              result))))
                 (manifest-entries manifest)
                 entries))))

(define (manifest-installed? manifest pattern)
  "Return #t if MANIFEST has an entry matching PATTERN (a manifest-pattern),
#f otherwise."
  (->bool (find (entry-predicate pattern)
                (manifest-entries manifest))))

(define (manifest-matching-entries manifest patterns)
  "Return all the entries of MANIFEST that match one of the PATTERNS."
  (define predicates
    (map entry-predicate patterns))

  (define (matches? entry)
    (any (lambda (pred)
           (pred entry))
         predicates))

  (filter matches? (manifest-entries manifest)))


;;;
;;; Profiles.
;;;

(define (profile-derivation manifest)
  "Return a derivation that builds a profile (aka. 'user environment') with
the given MANIFEST."
  (define inputs
    (append-map (match-lambda
                 (($ <manifest-entry> name version
                                      output (? package? package) deps)
                  `((,package ,output) ,@deps))
                 (($ <manifest-entry> name version output path deps)
                  ;; Assume PATH and DEPS are already valid.
                  `(,path ,@deps)))
                (manifest-entries manifest)))

  (define builder
    #~(begin
        (use-modules (ice-9 pretty-print)
                     (guix build union))

        (setvbuf (current-output-port) _IOLBF)
        (setvbuf (current-error-port) _IOLBF)

        (union-build #$output '#$inputs
                     #:log-port (%make-void-port "w"))
        (call-with-output-file (string-append #$output "/manifest")
          (lambda (p)
            (pretty-print '#$(manifest->gexp manifest) p)))))

  (gexp->derivation "profile" builder
                    #:modules '((guix build union))
                    #:local-build? #t))

(define (profile-regexp profile)
  "Return a regular expression that matches PROFILE's name and number."
  (make-regexp (string-append "^" (regexp-quote (basename profile))
                              "-([0-9]+)")))

(define (generation-number profile)
  "Return PROFILE's number or 0.  An absolute file name must be used."
  (or (and=> (false-if-exception (regexp-exec (profile-regexp profile)
                                              (basename (readlink profile))))
             (compose string->number (cut match:substring <> 1)))
      0))

(define (generation-numbers profile)
  "Return the sorted list of generation numbers of PROFILE, or '(0) if no
former profiles were found."
  (define* (scandir name #:optional (select? (const #t))
                    (entry<? (@ (ice-9 i18n) string-locale<?)))
    ;; XXX: Bug-fix version introduced in Guile v2.0.6-62-g139ce19.
    (define (enter? dir stat result)
      (and stat (string=? dir name)))

    (define (visit basename result)
      (if (select? basename)
          (cons basename result)
          result))

    (define (leaf name stat result)
      (and result
           (visit (basename name) result)))

    (define (down name stat result)
      (visit "." '()))

    (define (up name stat result)
      (visit ".." result))

    (define (skip name stat result)
      ;; All the sub-directories are skipped.
      (visit (basename name) result))

    (define (error name* stat errno result)
      (if (string=? name name*)             ; top-level NAME is unreadable
          result
          (visit (basename name*) result)))

    (and=> (file-system-fold enter? leaf down up skip error #f name lstat)
           (lambda (files)
             (sort files entry<?))))

  (match (scandir (dirname profile)
                  (cute regexp-exec (profile-regexp profile) <>))
    (#f                                         ; no profile directory
     '(0))
    (()                                         ; no profiles
     '(0))
    ((profiles ...)                             ; former profiles around
     (sort (map (compose string->number
                         (cut match:substring <> 1)
                         (cute regexp-exec (profile-regexp profile) <>))
                profiles)
           <))))

(define (previous-generation-number profile number)
  "Return the number of the generation before generation NUMBER of
PROFILE, or 0 if none exists.  It could be NUMBER - 1, but it's not the
case when generations have been deleted (there are \"holes\")."
  (fold (lambda (candidate highest)
          (if (and (< candidate number) (> candidate highest))
              candidate
              highest))
        0
        (generation-numbers profile)))

(define (generation-file-name profile generation)
  "Return the file name for PROFILE's GENERATION."
  (format #f "~a-~a-link" profile generation))

(define (generation-time profile number)
  "Return the creation time of a generation in the UTC format."
  (make-time time-utc 0
             (stat:ctime (stat (generation-file-name profile number)))))

;;; profiles.scm ends here
