;;; mu4e-sidebar.el --- A sticky sidebar for mu4e navigation -*- lexical-binding: t -*-
;;; Commentary:
;; The concept and ui of this project is heavily inspired by the
;; mu4e-dashboard package made by rougier:
;; https://github.com/rougier/mu4e-dashboard
;;
;; All code has been tested against mu4e v1.12 and Emacs v30.2

;;; Code:

;;; ============================================================
;;; Configuration
;;; ============================================================

;; ── Variables ────────────────────────────────────────────────

(defvar mu4e-sidebar-buffer-name "*mu4e-nav*"
  "Name of the mu4e sidebar buffer.")

(defvar mu4e-sidebar-width 40
  "Width of the sidebar window in columns.")

(defvar mu4e-sidebar-side 'left
  "Which side the sidebar appears on. Either `'left` or `'right`.")

(defvar mu4e-sidebar-inbox-folder "/Inbox"
  "Inbox folder path, since mu4e has no builtin variable for it.
Set within your mu4e context :vars")

(defvar mu4e-sidebar-people nil
  "People to show in the People section of the sidebar.
Each entry is a cons cell of (display-name . email-address).")

(defvar mu4e-sidebar-lists nil
  "Mailing lists to show in the Mailing lists section of the sidebar.
Each entry is a cons cell of (display-name . list-address)")

(defvar mu4e-sidebar-tags nil
  "Tags to shpw in the Tags section of the sidebar. Each entry
is a cons cell of (display-name . tag-name)")

;; ── Sections ────────────────────────────────────────────────

(defvar mu4e-sidebar-sections
  `((:title "󰶎 Mailboxes"
     :entries-fn ,(lambda ()
                    (list (cons " Inbox"   (format "maildir:%s" mu4e-sidebar-inbox-folder))
                          (cons " Flagged" "flag:flagged")
                          (cons "󰧮 Drafts"  (format "maildir:%s" mu4e-drafts-folder))
                          (cons " Sent"    (format "maildir:%s" mu4e-sent-folder))
                          (cons "󰩪 Archive" (format "maildir:%s" mu4e-refile-folder)))))

    (:title " Smart Mailboxes"
     :entries ((" Today"      . "date:today")
               ("󱨰 Yesterday"  . "date:1d..now")
               ("󰃰 Last week"  . "date:7d..now")
               ("󰃰 Last month" . "date:1m..now")))

    (:title " People"
     :entries-fn ,(lambda ()
                    (mapcar (lambda (person)
                              (cons (car person)
                                    (format "from:%s" (cdr person))))
                            mu4e-sidebar-people)))

    (:title " Mailing Lists"
     :entries-fn ,(lambda ()
                    (mapcar (lambda (mail-list)
                              (cons (car mail-list)
                                    (format "list:%s" (cdr mail-list))))
                            mu4e-sidebar-lists)))

    (:title " Tags"
     :entries-fn ,(lambda ()
                    (mapcar (lambda (tag)
                              (cons (car tag)
                                    (format "tag:%s" (cdr tag))))
                            mu4e-sidebar-tags))))
  "Sections to display in the mu4e sidebar.
Each element is a plist with :title and :entries.
:entries is an alist of (display-label . mu4e-query-string).")

;;; ============================================================
;;; Faces
;;; ============================================================

(defface mu4e-sidebar-header-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for the top-level unread mail header.")

(defface mu4e-sidebar-unread-count-face
  '((t :inherit font-lock-constant-face :weight bold))
  "Face for the global unread count in the header.")

(defface mu4e-sidebar-section-title-face
  '((t :inherit font-lock-comment-face :weight bold :slant normal))
  "Face for section title labels.")

(defface mu4e-sidebar-entry-face
  '((t :inherit default))
  "Face for individual mailbox/query entries.")

(defface mu4e-sidebar-count-face
  '((t :inherit font-lock-comment-face))
  "Face for entry counts in the sidebar.")

;;; ============================================================
;;; Internal helpers
;;; ============================================================

(defvar mu4e-sidebar--collapsed-sections '()
  "List of section titles that are currently collapsed.")

(defun mu4e-sidebar--cleanup-windows ()
  "Ensure only the sidebar and headers windows are visible."
  (let* ((sidebar-win (get-buffer-window mu4e-sidebar-buffer-name))
         (headers-win (get-buffer-window mu4e-headers-buffer-name)))
    (dolist (win (window-list))
      (unless (or (eq win sidebar-win)
                  (eq win headers-win)
                  (window-parameter win 'window-side))
        (ignore-errors (delete-window win))))))

(defun mu4e-sidebar--run-search (query)
  "Run a mu4e search for QUERY, cleaning up windows after headers load."
  (add-hook 'mu4e-headers-found-hook #'mu4e-sidebar--cleanup-windows nil t)
  (mu4e-search query))

(defun mu4e-sidebar--insert-header ()
  "Insert the top-level unread mail header as a clickable button."
  (insert "\n")
  (insert-text-button
   "   Unread Mail"
   'face 'mu4e-sidebar-header-face
   'action (lambda (_) (mu4e-sidebar--run-search "flag:unread"))
   'follow-link t
   'help-echo "Search all unread mail")
  (insert "\n\n"))

(defun mu4e-sidebar-toggle-section ()
  "Toggle the collapsed state of the section at point."
  (interactive)
  (when-let ((btn (button-at (point))))
    (when (button-get btn 'mu4e-sidebar-section-p)
      (button-activate btn))))

(defvar mu4e-sidebar--count-overlays '()
  "List of overlays used for entry counts.")

(defun mu4e-sidebar--clear-overlays ()
  "Remove all count overlays from the sidebar buffer."
  (mapc #'delete-overlay mu4e-sidebar--count-overlays)
  (setq mu4e-sidebar--count-overlays nil))

(defun mu4e-sidebar--pad-entry (label count width)
  "Format dot padding between LABEL and COUNT to fill WIDTH."
  (let* ((count-str (number-to-string count))
         (dots-count (- width 12
                        (length label)
                        (length count-str)
                        2)) ;; 2 for the spaces around the dots
         (dots (make-string (max 1 dots-count) ?.)))
    (format " %s %s" dots count-str)))

(defun mu4e-sidebar--get-count (query callback)
  "Asynchronously get the count of messages matching QUERY.
 Call CALLBACK with the integer result."
  (let ((cmd (format "mu find --nocolor -u '%s' 2>/dev/null | wc -l" query)))
    (make-process
     :name "mu4e-sidebar-count"
     :command (list "sh" "-c" cmd)
     :noquery t
     :filter (lambda (proc output)
               (when (string-match "[0-9]+" output)
                 (funcall callback
                          (string-to-number (match-string 0 output))))))))

(defun mu4e-sidebar--add-count-overlay (pos query width label)
  "Add an async count overlay at POS for QUERY to end of WIDTH with LABEL."
  (let ((ov (make-overlay pos pos)))
    (push ov mu4e-sidebar--count-overlays)
    (mu4e-sidebar--get-count
     query
     (lambda (count)
       (when (overlay-buffer ov)
         (overlay-put ov 'after-string
                      (propertize
                       (mu4e-sidebar--pad-entry label count width)
                       'face 'mu4e-sidebar-count-face)))))))

(defun mu4e-sidebar--insert-section (section)
  "Insert a single SECTION (a plist with :title and :entries or :entries-fn)."
  (let* ((title      (plist-get section :title))
         (entries-fn (plist-get section :entries-fn))
         (entries    (if entries-fn
                         (funcall entries-fn)
                       (plist-get section :entries)))
         (collapsed  (member title mu4e-sidebar--collapsed-sections)))
    (when entries
      (insert-text-button
       (format "  %s %s\n" title (if collapsed "…" ""))
       'face 'mu4e-sidebar-section-title-face
       'mu4e-sidebar-section-p t
       'action (lambda (_)
                 (if (member title mu4e-sidebar--collapsed-sections)
                     (setq mu4e-sidebar--collapsed-sections
                           (delete title mu4e-sidebar--collapsed-sections))
                   (push title mu4e-sidebar--collapsed-sections))
                 (mu4e-sidebar-render))
       'follow-link t)
      (unless collapsed
        (insert "\n")
        (dolist (entry entries)
          (let* ((label (car entry))
                 (query (cdr entry))
                 (insert-pos (progn
                               (insert-text-button
                                (format "    %s" label)
                                'face 'mu4e-sidebar-entry-face
                                'action (lambda (_) (mu4e-sidebar--run-search query))
                                'follow-link t
                                'help-echo query)
                               (point))))
            (insert "\n")
            (mu4e-sidebar--add-count-overlay
             insert-pos query mu4e-sidebar-width label)))
        (insert "\n")))))

(defun mu4e-sidebar-next-section ()
  "Move point to the next section header."
  (interactive)
  (let ((pos (next-button (point))))
    (while (and pos (not (button-get pos 'mu4e-sidebar-section-p)))
      (setq pos (next-button pos)))
    (when pos (goto-char pos))))

(defun mu4e-sidebar-prev-section ()
  "Move point to the previous section header."
  (interactive)
  (let ((pos (previous-button (point))))
    (while (and pos (not (button-get pos 'mu4e-sidebar-section-p)))
      (setq pos (previous-button pos)))
    (when pos (goto-char pos))))

;;; ============================================================
;;; Render & open
;;; ============================================================

(defvar mu4e-sidebar-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "f") #'mu4e-sidebar-toggle-section)
    (define-key map (kbd "J") #'mu4e-sidebar-next-section)
    (define-key map (kbd "K") #'mu4e-sidebar-prev-section)
    map)
  "Keymap for mu4e-sidebar buffers.")

(define-derived-mode mu4e-sidebar-mode special-mode "mu4e-sidebar"
  "Major mode for the mu4e navigation sidebar."

  (setq-local cursor-type nil)
  (setq-local mode-line-format nil)

  (font-lock-mode -1)
  (jit-lock-mode -1))

(when (featurep 'evil) ;; evil overrides
  (evil-define-key 'normal mu4e-sidebar-mode-map
    (kbd "f") #'mu4e-sidebar-toggle-section
    (kbd "J") #'mu4e-sidebar-next-section
    (kbd "K") #'mu4e-sidebar-prev-section))

(defun mu4e-sidebar-render ()
  "Render (or re-render) the mu4e sidebar buffer."
  (with-current-buffer (get-buffer-create mu4e-sidebar-buffer-name)
    (let ((inhibit-read-only t)
          (saved-line (line-number-at-pos)))
      (mu4e-sidebar--clear-overlays)
      (erase-buffer)
      (mu4e-sidebar--insert-header)
      (dolist (section mu4e-sidebar-sections)
        (mu4e-sidebar--insert-section section))
      (goto-line saved-line))
    (mu4e-sidebar-mode)))

(defun mu4e-sidebar-open ()
  "Open (or refresh) the mu4e navigation sidebar."
  (interactive)
  (mu4e-sidebar-render)
  (display-buffer-in-side-window
   (get-buffer mu4e-sidebar-buffer-name)
   `((side . ,mu4e-sidebar-side)
     (slot . 0)
     (window-width . ,mu4e-sidebar-width)
     (window-parameters . ((no-delete-other-windows . t)
                            (no-other-window . t))))))

(defun mu4e-sidebar-close ()
  "Close the mu4e sidebar window (buffer is kept alive)."
  (interactive)
  (when-let ((win (get-buffer-window mu4e-sidebar-buffer-name)))
    (delete-window win)))

(defun mu4e-sidebar-toggle ()
  "Toggle the mu4e sidebar open or closed."
  (interactive)
  (if (get-buffer-window mu4e-sidebar-buffer-name)
      (mu4e-sidebar-close)
    (mu4e-sidebar-open)))

(provide 'mu4e-sidebar)
;;; mu4e-sidebar.el ends here
