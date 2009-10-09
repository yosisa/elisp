(defun to-buffer-name (arg)
  (if (stringp arg) arg (buffer-name arg)))
(defun respawn-buffer (buffer &optional initializer)
  (interactive)
  (let ((c (current-buffer)) (new (not (get-buffer buffer))))
    (set-buffer (get-buffer-create buffer))
    (and new (funcall initial-major-mode))
    (erase-buffer)
    (insert (or (and initializer (funcall initializer))
                (and (not inhibit-startup-message)
                     initial-scratch-message)
                ""))
    (and (string= (buffer-name c) (to-buffer-name buffer))
         (message "Cleared."))
    (set-buffer c)))
(defun make-buffer-immortal (buffer)
  (add-hook 'kill-buffer-query-functions
            `(lambda ()
               (if (string= (buffer-name) (to-buffer-name ,buffer))
                   (progn (respawn-buffer ,buffer) nil)
                 t)))
  (add-hook 'after-save-hook
            `(lambda () (respawn-buffer ,buffer))))

(provide 'immortal-buffer)
