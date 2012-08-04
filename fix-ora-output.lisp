;;;; Utility to pretty reformat SQL query output generated 
;;;; by Oracle development tools like SQL*Plus or TOAD, when
;;;; the default value of the LINESIZE system variable was 
;;;; used.
;;;;
;;;; Copyright (c) 2008, Anton Vodonosov. All rights reserved.

;;;; The main function is FIX-ORA-OUTPUT.
;;;;
;;;; Example:
;;;;
;;;; (with-open-file (in "query-result.txt"
;;;;                     :direction :input)
;;;;   (with-open-file (out "pretty-query-result.txt"
;;;;                        :direction :output
;;;;                        :if-exists :overwrite
;;;;                        :if-does-not-exist :create)
;;;;     (fix-ora-output in out)))

;;;; If you are going to read the code, it is recommented
;;;; to have broken oracle output in front of your eyes.
;;;; Don't expect the code to be very pretty, because
;;;; it is just a product of procrastination during daily work. 

;; TODO: CLOB fields are not fully supported 
;; (if all values of the field are empty, 
;; oracle prints empty string as a column name)

;; TODO: multi-line string values are not supported.

(defun starts-with (str prefix)
  (and (not (null str))
       (>= (length str)
           (length prefix))
       (string= prefix (subseq str 0 (length prefix)))))

;; SQL table column in the Oracle output
(defstruct table-col 
  (name)
  (start) ; zero based start position of the column value in query output line
  (end)) ; zero based end position of the column value in query output line

(defun parse-col-headers (col-names underline)
  "Parses one line of column headers definition.
COL-NAMES is column names, UNDERLINE is a line 
that follows column names in oracle output (a line of ----)"
  (setf underline (string-trim '(#\Space) underline))
  (let ((start 0)
        end
        cols)
    (loop
       (setf end (1- (or (position #\Space underline :start start :test #'char=)
                         (length underline))))
       (push (make-table-col :name (string-trim '(#\Space) 
                                                (subseq col-names start (1+ end)))
                             :start start :end end)
             cols)
       ;; skip space
       (setf start (+ 2 end))
       (when (>= start (length underline))
         (return (nreverse cols))))))

(defun read-col-headers (in)
  "Returns list of table-col structures
and two 'look ahead' lines, i.e. 
lines read from IN that come after
column headers definition" 
  (let (first-line 
        (second-line (read-line in))
        cols)
    ;; skip anything before column headers
    ;; (like sqlplus prompt and query text)
    (loop
       (setf first-line second-line)
       (setf second-line (read-line in nil nil))       
       ;; if end of file is met, return NIL
       (unless second-line
         (return-from read-col-headers nil))
       (when (starts-with second-line "---")
         (return)))
    ;; now first-line is column name(s)
    ;; and second-line is an underline of headers (i.e. line of '-------')
    (loop
       (setf cols (nconc cols (parse-col-headers first-line second-line)))
       (setf first-line (read-line in nil nil))      
       (setf second-line (read-line in nil nil))       
       (unless (starts-with second-line "---")
         (return)))
    (values cols first-line second-line)))

;; The function created by MAKE-HEADER-SKIPPER
;; returns:
;;   - NIL if no data line is reached yet
;;   - :EOF on end of file
;;   - data line read from IN
;;
;; Implementation:
;;
;; The function operates on three element look-ahead buffer (la1 la2 la3).
;; Every element of the buffer is a line read from input stream:
;;
;; [processing] <- (la1 la2 la3) <- [input stream]
;;
;; I.e. a string read from input stream enters the look-ahead buffer
;; from the la3 side end exits the buffer from the la1 side.
;;
;; Four situations are distinguished; the situations are checked in the
;; order they are specified below:
;;
;; 1. la1 --- or empty string; 
;;    la2 <ANYTHING>
;;    la3 ---
;;    
;;    This means we are inside of column headers. 
;;    Move two lines forward and return NIL.
;;
;; 2. la1 ---
;;    la2 <ANYTHING>
;;    la3 <ANYTHING>
;; 
;;    This means la1 is the last line of the column headers. 
;;    Move one line forward and return NIL.
;;
;; 3. la1 NULL
;;    la2 NULL
;;    la3 NULL
;;
;;    End of file reached. Return :EOF.
;;
;; 4. la1 <SOMETHING>
;;    la2 <ANYTHING>
;;    la3 <ANYTHING>
;;
;;    la1 is a data line. We don't know yet what is stored in la2 and la3. 
;;    Move one line forward and return la1.
(defun make-header-skipper (in look-ahead-line1 look-ahead-line2) 
  (let ((look-ahead (list look-ahead-line1 
                          look-ahead-line2 
                          (read-line in nil nil))))
    (lambda () 
      (cond ((and (or (zerop (length (first look-ahead)))
                      (starts-with (first look-ahead) "---"))
                  (starts-with (third look-ahead) "---"))
             ;; look ahead is on the column header
             ;; skip two lines
             (setf look-ahead (nconc (cddr look-ahead) (list (read-line in nil nil)
                                                             (read-line in nil nil))))
             nil)
            ((starts-with (first look-ahead) "---")
             (setf look-ahead (nconc (cdr look-ahead) (list (read-line in nil nil))))
             nil)
            ((and (null (first look-ahead))
                  (null (second look-ahead))
                  (null (third look-ahead)))
             :eof)
            (t (let ((tmp (first look-ahead)))
                 (setf look-ahead (nconc (cdr look-ahead) (list (read-line in nil nil))))
                 tmp))))))

(defun make-data-line-reader (in look-ahead-line1 look-ahead-line2)
  "The function created returns next data line form input stream IN
or :EOF if end of file is reached."
  (let ((skipper (make-header-skipper in look-ahead-line1 look-ahead-line2)))
    (lambda () 
      (loop
         (let ((line (funcall skipper)))
           (case line
             (:eof (return :eof))
             ((nil))                    ; continue loop
             (otherwise (return line))))))))

(defun print-row (cols line-reader &optional (dest t))
  "Returns :EOF if end of file has been reached and NIL otherwise."
  (let ((prev-end 999999999)
        line)
    (dolist (cur-col cols)
      (when (> prev-end (table-col-start cur-col))
        (setf line (funcall line-reader))
        (when (eq :eof line)
          (return-from print-row :eof)))
      (when (< (table-col-end cur-col) (length line))
        (princ (subseq line 
                       (table-col-start cur-col)
                       (1+ (table-col-end cur-col)))
               dest)
        (princ #\Space dest))
      (setf prev-end (table-col-end cur-col)))
    (princ #\Newline dest)
    nil))

(defun print-header (cols dest)
  (dolist (col cols)
    (princ (table-col-name col) dest)
    (dotimes (i (+ 2 (- (table-col-end col)
                        (table-col-start col)
                        (length (table-col-name col)))))
      (princ #\Space dest)))
  (princ #\Newline dest)
  (dolist (col cols)
    (dotimes (i (1+ (- (table-col-end col)
                       (table-col-start col))))
      (princ #\- dest))
    (princ #\Space dest))  
  (princ #\Newline dest))

(defun fix-ora-output (in dest)
  "IN - an input character stream with ugly Oracle output.
OUT - output character stream to receive pretty reformatted output."
  (multiple-value-bind (cols line1 line2) 
      (read-col-headers in)
    (print-header cols dest)
    (let ((reader (make-data-line-reader in line1 line2))
          (eof?))
      (loop 
         (setf eof? (print-row cols reader dest))
         (when eof? (return-from fix-ora-output))
         ;; After row data lines Oracle prints an empty line, 
         ;; perhaps prepended with column header lines.
         ;; Skip it.
         (funcall reader)))))


;; create foo.exe file in CLISP

;; (defun main ()
;;   (format *error-output* "~A starting...~%" (get-decoded-time))
;;   (parse-ora-output *terminal-io* *terminal-io*)
;;   (format *error-output* "~A OK~%" (get-decoded-time))
;;   (ext:exit 0))
;;(ext:saveinitmem "foo" :quiet t :executable t :init-function 'main)
    
