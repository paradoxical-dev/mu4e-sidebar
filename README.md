# Mu4e Sidebar

A sidebar styled dashboard for navigating mu4e in Emacs. Providing quick access to mailboxes, date queries, people, mailing lists and tags from a persistent window.

Inspired by [mu4e-dashboard](https://github.com/rougier/mu4e-dashboard.git) by Nicolas Rougier.

SCREENSHOT HERE

# Features

- Collapsible sections
- Message counts for each entry
- Fully configurable sections: people, mailing lists and tags
- Context aware; folder paths update automatically per account.
- Evil support with default bindings

# Requirements

> [!WARNING]
> I have only personally tested the package on Emacs 30.1 with mu4e v1.12. Experience with other versions may vary.

- Emacs 28+
- mu4e v1.12+
- mu
- A nerd font (recommended for rendering the default icons but not required)

# Installation

The package is not currently listed on MELPA so you'll need to provide a recipe directly. For example using `straight.el` with `use-package`

``` elisp
(use-package mu4e-sidebar
    :straight (mu4e-sidebar :type git :host github :repo "paradoxical-dev/mu4e-sidebar")
    :after mu4e)
```

# Keybindings

The following bindings are active in the sidebar buffer. Evil bindings are
applied automatically if evil is detected.

| Key      | Action                          |
|----------|---------------------------------|
| `RET`    | Execute query / open mailbox    |
| `f`      | Toggle section fold             |
| `J`      | Jump to next section header     |
| `K`      | Jump to previous section header |
| `q`      | Close sidebar                   |

# Configuration

User-specific variables should be set within the `:vars` of your mu4e context so they update automatically when switching accounts. See the Example section below.

## UI

| Variable              | Default  | Description                          |
|-----------------------|----------|--------------------------------------|
| `mu4e-sidebar-width`  | `40`     | Width of the sidebar window          |
| `mu4e-sidebar-side`   | `'left`  | Side to display on (`'left`/`'right`)|

## User Variables

| Variable                    | Description                                              |
|-----------------------------|----------------------------------------------------------|
| `mu4e-sidebar-inbox-folder` | Path to your Inbox folder                                |
| `mu4e-sidebar-people`       | Alist of `(name . email)` shown in the People section    |
| `mu4e-sidebar-lists`        | Alist of `(name . list-id)` shown in the Mailing Lists section |
| `mu4e-sidebar-tags`         | Alist of `(name . tag)` shown in the Tags section        |

Setting any of `mu4e-sidebar-people`, `mu4e-sidebar-lists`, or `mu4e-sidebar-tags` to `nil` (the default) will hide that section entirely.

## Example

A full configuration with 2 example contexts (personal and work)

``` elisp
(use-package mu4e-sidebar
  :straight (mu4e-sidebar :type git :host github :repo "paradoxical-dev/mu4e-sidebar")
  :after mu4e
  :config
  (setq mu4e-sidebar-width 35
        mu4e-sidebar-side 'right)

  (setq mu4e-contexts
    (list
     (make-mu4e-context
      :name "Personal"
      :match-func (lambda (msg)
                    (when msg
                      (string-prefix-p "/personal" (mu4e-message-field msg :maildir))))
      :vars '((mu4e-sent-folder              . "/personal/Sent")
              (mu4e-drafts-folder            . "/personal/Drafts")
              (mu4e-trash-folder             . "/personal/Trash")
              (mu4e-refile-folder            . "/personal/Archive")
              (mu4e-sidebar-inbox-folder     . "/personal/Inbox")
              (mu4e-sidebar-people           . (("Alice" . "alice@example.com")
                                                ("Bob"   . "bob@example.com")))
              (mu4e-sidebar-lists            . (("Emacs Devel" . "emacs-devel.gnu.org")
                                                ("Org Mode"    . "emacs-orgmode.gnu.org")))
              (mu4e-sidebar-tags             . (("Work"     . "work")
                                                ("Finance"  . "finance")))))

     (make-mu4e-context
      :name "Work"
      :match-func (lambda (msg)
                    (when msg
                      (string-prefix-p "/work" (mu4e-message-field msg :maildir))))
      :vars '((mu4e-sent-folder              . "/work/Sent")
              (mu4e-drafts-folder            . "/work/Drafts")
              (mu4e-trash-folder             . "/work/Trash")
              (mu4e-refile-folder            . "/work/Archive")
              (mu4e-sidebar-inbox-folder     . "/work/Inbox")
              (mu4e-sidebar-people           . (("Boss"     . "boss@company.com")
                                                ("Colleague". "colleague@company.com")))
              (mu4e-sidebar-lists            . nil)
              (mu4e-sidebar-tags             . (("Urgent"  . "urgent")
                                                ("Project" . "project")))))))

  (add-hook 'mu4e-main-mode-hook #'mu4e-sidebar-open))
```


