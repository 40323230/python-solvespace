# -*- coding: utf-8 -*-
from PyQt5.QtCore import pyqtSlot
from PyQt5.QtWidgets import QWidget
from .Ui_run_Measurement import Ui_Form

class Measurement_show(QWidget, Ui_Form):
    def __init__(self, parent=None):
        super(Measurement_show, self).__init__(parent)
        self.setupUi(self)