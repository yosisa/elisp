;;; yaicomplete.el --- Yet another incremental completion in minibuffer

(defvar yaicomplete-completion-contents nil)
(defvar yaicomplete-completion-suffix nil)
(defvar yaicomplete-completion-suffix-overlay nil)
(defvar yaicomplete-completion-suffix-overlay-priority 500)

(defgroup yaicomplete nil
  "Show completions dynamically in minibuffer."
  :prefix "yaicomplete-"
  :group 'minibuffer)

(defface yaicomplete-completion-suffix-face
  '((t (:foreground "brightblack")))
  "Face of completion suffix."
  :group 'yaicomplete)

(defcustom yaicomplete-completion-suffix-face
  'yaicomplete-completion-suffix-face
  "Face of completion suffix."
  :type 'face
  :group 'yaicomplete)

(defcustom yaicomplete-auto-select-exact-completion nil
  "Automatically select an completion if it is an exact one."
  :type 'boolean
  :group 'yaicomplete)

(defcustom yaicomplete-auto-select-exact-completion-delay 0.8
  "Delay for automatically selecting an exact completion."
  :type 'float
  :group 'yaicomplete)

(defcustom yaicomplete-exclude '()
  "List of symbols where existence of its value indicate not to activate yaicomplete."
  :type '(symbol)
  :group 'yaicomplete)

(defcustom yaicomplete-minibuffer-setup-hook nil
  "yaicomplete minibuffer-setup-hook"
  :type 'hook
  :group 'yaicomplete)

(defvar yaicomplete-pre-command-hook nil
  "yaicomplete pre-command-hook")

(defvar yaicomplete-post-command-hook nil
  "yaicomplete post-command-hook")

(defvar yaicomplete-timer nil)

(defadvice completion--do-completion
  (around yaicomplete-ad-completion-status activate)
  (setq yaicomplete-completion-status ad-do-it))

(defun yaicomplete-fix-last-command ()
  (when (and (eq this-command 'minibuffer-complete)
             (= (length yaicomplete-completion-suffix) 0))
    (setq last-command 'minibuffer-complete)))

(defun yaicomplete-pre-command-delete-completion-suffix ()
  (let* ((exit "exit-minibuffer")
         (cmd (symbol-name this-command))
         (len1 (length exit))
         (len2 (length cmd)))
    (when (or (< len2 len1)
              (not (string= (substring cmd (- len2 len1)) exit)))
      (yaicomplete-delete-completion-suffix))))

(defun yaicomplete-cancel-timer ()
  (when yaicomplete-timer
    (cancel-timer yaicomplete-timer)
    (setq yaicomplete-timer nil)))

(defun yaicomplete-do-complete ()
  (setq yaicomplete-completion-contents (minibuffer-contents))
  (let ((cmd this-command) (pt (point))
        (yaicomplete-completion-status 0))
    (when (and (not (eq cmd 'minibuffer-complete))
               (not (eq cmd 'yaicomplete-exit-without-complete))
               (not (eq cmd 'yaicomplete-cancel))
               (eq pt (field-end)))
      ;; do complete
      (let (minibuffer-scroll-window) (minibuffer-complete))
      (minibuffer-completion-help)
      ;; replace completion prefix with the original text
      (let ((suffix (yaicomplete-completion-suffix)))
        (delete-minibuffer-contents)
        (insert (concat yaicomplete-completion-contents suffix)))
      ;; timer for the auto completion
      (when (and (= (logand yaicomplete-completion-status #b001) #b001)
                 yaicomplete-auto-select-exact-completion)
        (setq yaicomplete-timer
              (run-with-idle-timer
               yaicomplete-auto-select-exact-completion-delay
               nil 'yaicomplete-do-exact-complete)))
      ;; restore cursor position
      (goto-char pt)))
  (setq yaicomplete-completion-suffix (yaicomplete-completion-suffix))
  (yaicomplete-set-completion-suffix-face)
  (yaicomplete-minibuffer-completion-help))

(defun yaicomplete-completion-suffix ()
  (let* ((contents1 (minibuffer-contents))
        (contents2 yaicomplete-completion-contents)
        (len (length contents2)))
    (if (eq t (compare-strings contents1 0 len contents2 0 len t))
        (substring contents1 len)
      "")))

(defun yaicomplete-delete-completion-suffix ()
  (let ((end (field-end)))
    (delete-region (- end (length yaicomplete-completion-suffix)) end)))

(defun yaicomplete-set-completion-suffix-face ()
  (let ((end (field-end)) (len (length yaicomplete-completion-suffix)))
    (yaicomplete-make-overlay)
    (move-overlay yaicomplete-completion-suffix-overlay (- end len) end)))

(defun yaicomplete-make-overlay ()
  (unless (overlayp yaicomplete-completion-suffix-overlay)
      (setq yaicomplete-completion-suffix-overlay
            (make-overlay (point-min) (point-max))))
  (let ((o yaicomplete-completion-suffix-overlay))
    (overlay-put o 'priority yaicomplete-completion-suffix-overlay-priority)
    (overlay-put o 'face yaicomplete-completion-suffix-face)))

(defun yaicomplete-minibuffer-completion-help ()
  (unless (and minibuffer-scroll-window
               (window-live-p minibuffer-scroll-window))
    (minibuffer-completion-help)))

(defun yaicomplete-do-exact-complete ()
  ;; do complete again
  (yaicomplete-delete-completion-suffix)
  (let (minibuffer-scroll-window) (minibuffer-complete))
  ;; save completion prefix and suffix
  (setq yaicomplete-completion-contents (minibuffer-contents))
  (setq yaicomplete-completion-suffix (yaicomplete-completion-suffix))
  ;; automatically display completion list
  (yaicomplete-minibuffer-completion-help))

(defun yaicomplete-exclude-p (symbol-list)
  (and (not (null symbol-list))
       (or (symbol-value (car symbol-list))
           (yaicomplete-exclude-p (cdr symbol-list)))))

(defun yaicomplete-minibuffer-setup ()
  (when (and (window-minibuffer-p (selected-window))
             (not executing-kbd-macro)
             minibuffer-completion-table
             (not (yaicomplete-exclude-p yaicomplete-exclude)))
    (setq yaicomplete-completion-contents ""
          yaicomplete-completion-suffix "")
    (add-hook 'pre-command-hook
              (lambda () (run-hooks 'yaicomplete-pre-command-hook))
              nil t)
    (add-hook 'post-command-hook
              (lambda () (run-hooks 'yaicomplete-post-command-hook))
              nil t)
    (run-hooks 'yaicomplete-minibuffer-setup-hook)))

(add-hook 'yaicomplete-pre-command-hook
          'yaicomplete-fix-last-command)
(add-hook 'yaicomplete-pre-command-hook
          'yaicomplete-pre-command-delete-completion-suffix)
(add-hook 'yaicomplete-pre-command-hook
          'yaicomplete-cancel-timer)
(add-hook 'yaicomplete-post-command-hook
          'yaicomplete-do-complete)

(defun yaicomplete-exit-without-complete ()
  (interactive)
  (exit-minibuffer))

(define-key minibuffer-local-map (kbd "C-j")
  'yaicomplete-exit-without-complete)

;;;###autoload
(define-minor-mode yaicomplete-mode
  "Toggle incremental minibuffer completion for this Emacs session."
  :global t
  :group 'yaicomplete
  (if yaicomplete-mode
      (add-hook 'minibuffer-setup-hook 'yaicomplete-minibuffer-setup)
    (remove-hook 'minibuffer-setup-hook 'yaicomplete-minibuffer-setup)))

(provide 'yaicomplete)