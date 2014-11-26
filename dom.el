;;; dom.el --- Traverse HTML DOMs
;; Copyright (C) 2013 Lars Magne Ingebrigtsen

;; Author: Lars Magne Ingebrigtsen <larsi@gnus.org>
;; Keywords: music

;; This file is not part of GNU Emacs.

;; dom.el is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; dom.el is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;;; Code:

(require 'cl-lib)

(defsubst dom-tag (node)
  "Return the NODE tag."
  ;; Called on a list of nodes.  Use the first.
  (if (consp (car node))
      (caar node)
    (car node)))

(defsubst dom-attributes (node)
  "Return the NODE attributes."
  ;; Called on a list of nodes.  Use the first.
  (if (consp (car node))
      (cadr (car node))
    (cadr node)))

(defsubst dom-children (node)
  "Return the NODE children."
  ;; Called on a list of nodes.  Use the first.
  (if (consp (car node))
      (cddr (car node))
    (cddr node)))

(defun dom-set-attributes (node attributes)
  "Set the attributes of NODE to ATTRIBUTES."
  (setq node (dom-ensure-node node))
  (setcar (cdr node) attributes))

(defun dom-set-attribute (node attribute value)
  "Set ATTRIBUTE in NODE to VALUE."
  (setq node (dom-ensure-node node))
  (let ((old (assoc attribute (cadr node))))
    (if old
	(setcdr old value)
      (setcar (cdr node) (nconc (cadr node) (list (cons attribute value)))))))

(defmacro dom-attr (node attr)
  "Return the attribute ATTR from NODE.
A typical attribute is `href'."
  `(cdr (assq ,attr (dom-attributes ,node))))

(defun dom-text (node)
  "Return all the text bits in the current node concatenated."
  (mapconcat 'identity (cl-remove-if-not 'stringp (dom-children node)) " "))

(defun dom-texts (node &optional separator)
  "Return all textual data under NODE concatenated with SEPARATOR in-between."
  (mapconcat
   'identity
   (mapcar
    (lambda (elem)
      (if (stringp elem)
	  elem
	(dom-texts elem separator)))
    (dom-children node))
   (or separator " ")))

(defun dom-by-tag (dom tag)
  "Return elements in DOM that is of type TAG.
A name is a symbol like `td'."
  (let ((matches (cl-loop for child in (dom-children dom)
			  for matches = (and (not (stringp child))
					     (dom-by-tag child tag))
			  when matches
			  append matches)))
    (if (eq (dom-tag dom) tag)
	(cons dom matches)
      matches)))

(defun dom-by-class (dom match)
  "Return elements in DOM that have a class name that matches regexp MATCH."
  (dom-elements dom 'class match))

(defun dom-by-style (dom match)
  "Return elements in DOM that have a style that matches regexp MATCH."
  (dom-elements dom 'style match))

(defun dom-by-id (dom match)
  "Return elements in DOM that have an ID that matches regexp MATCH."
  (dom-elements dom 'id match))

(defun dom-elements (dom attribute match)
  "Find elements matching MATCH (a regexp) in ATTRIBUTE.
ATTRIBUTE would typically be `class', `id' or the like."
  (let ((matches (cl-loop for child in (dom-children dom)
			  for matches = (dom-elements child attribute match)
			  when matches
			  append matches))
	(attr (dom-attr dom attribute)))
    (if (and attr
	     (string-match match attr))
	(cons dom matches)
      matches)))

(defun dom-parent (dom node)
  "Return the parent of NODE in DOM."
  (if (memq node (dom-children dom))
      dom
    (let ((result nil))
      (dolist (elem (dom-children dom))
	(when (and (not result)
		   (not (stringp elem)))
	  (setq result (dom-parent elem node))))
      result)))

(defun dom-node (tag &optional attributes &rest children)
  "Return a DOM node with TAG and ATTRIBUTES."
  (if children
      `(,tag ,attributes ,@children)
    (list tag attributes)))

(defun dom-append-child (node child)
  "Append CHILD to the end of NODE's children."
  (setq node (dom-ensure-node node))
  (nconc node (list child)))

(defun dom-add-child-before (node child &optional before)
  "Add CHILD to NODE's children before child BEFORE.
If BEFORE is nil, make CHILD NODE's first child."
  (setq node (dom-ensure-node node))
  (let ((children (dom-children node)))
    (when (and before
	       (not (memq before children)))
      (error "%s does not exist as a child" before))
    (let ((pos (if before
		   (cl-position before children)
		 0)))
      (if (zerop pos)
	  ;; First child.
	  (setcdr (cdr node) (cons child (cddr node)))
	(setcdr (nthcdr (1- pos) children)
		(cons child (nthcdr pos children))))))
  node)

(defun dom-ensure-node (node)
  "Ensure that NODE is a proper DOM node."
  ;; Add empty attributes, if none.
  (when (consp (car node))
    (setq node (car node)))
  (when (= (length node) 1)
    (setcdr node (list nil)))
  node)

(provide 'dom)

;;; dom.el ends here
