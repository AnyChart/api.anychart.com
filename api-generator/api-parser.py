#!/usr/bin/env python
#coding=utf-8

import os
import re
import subprocess

PATH = os.path.abspath(os.path.dirname(__file__))
PROJECT_PATH = os.path.join(PATH,'..','..','ACDVF')
SRC_PATH = os.path.join(PROJECT_PATH, 'src')
GRAPHICS_SRC_PATH = os.path.join(PROJECT_PATH, 'libs','graphicsjs', 'src')
OUT_PATH = os.path.join(PATH, 'out')

regexProto = r"\n\s*([^\/]proto\[([^\]]*)\](.*))"
regexExportSymbol = r"\n\s*(goog.exportSymbol\(([^,]*)(.*))"


def modify_source_code():
    ## modify anychart.core.settings.createDescriptor
    with open(os.path.join(SRC_PATH, 'core','settings.js'), 'r+') as myfile:
        filecontent = myfile.read()
        myfile.seek(0)
        myfile.write(filecontent.replace("classConstructor.prototype[alias]","classConstructor.prototype[alias+'+'] = true; classConstructor.prototype[alias]").replace("map[methodName] = descriptor;","map[methodName] = descriptor;\n"+"map[methodName+'+'] = descriptor;"))
        myfile.close()

    ## change all protos and exportSymbols
    for dirpath, dirnames, files in os.walk(SRC_PATH):
        for name in files:
            with open(os.path.join(dirpath,name), 'r+') as myfile:
                filecontent = myfile.read()
                matches = re.finditer(regexProto, filecontent)
                for i,match in enumerate(matches):
                    filecontent = filecontent.replace(match.group(1), match.group(1).replace(match.group(2), match.group(2)[0:-1]+'+'+match.group(2)[0]).replace(match.group(3), '={};')+'\n'+match.group(1))
                matches = re.finditer(regexExportSymbol, filecontent)
                for i,match in enumerate(matches):
                    filecontent = filecontent.replace(match.group(1), match.group(1).replace(match.group(2), match.group(2)[0:-1]+'+'+match.group(2)[0]).replace(match.group(3), ',{});')+'\n'+match.group(1))
                # write changes
                myfile.seek(0)
                myfile.write(filecontent)
                myfile.close()

    ## change all protos and exportSymbols
    for dirpath, dirnames, files in os.walk(GRAPHICS_SRC_PATH):
        for name in files:
            with open(os.path.join(dirpath,name), 'r+') as myfile:
                filecontent = myfile.read()
                matches = re.finditer(regexProto, filecontent)
                for i,match in enumerate(matches):
                    filecontent = filecontent.replace(match.group(1), match.group(1).replace(match.group(2), match.group(2)[0:-1]+'+'+match.group(2)[0]).replace(match.group(3), '={};')+'\n'+match.group(1))
                matches = re.finditer(regexExportSymbol, filecontent)
                for i,match in enumerate(matches):
                    filecontent = filecontent.replace(match.group(1), match.group(1).replace(match.group(2), match.group(2)[0:-1]+'+'+match.group(2)[0]).replace(match.group(3), ',{});')+'\n'+match.group(1))
                # write changes
                myfile.seek(0)
                myfile.write(filecontent)
                myfile.close()

def run_phantom():
   subprocess.call("phantomjs phantomjs_handler.js $PWD/index.html > api.json", shell=True)
   subprocess.call("cd "+PROJECT_PATH+" && git submodule foreach git reset --hard && git checkout -- . && cd "+PATH, shell=True)

modify_source_code()
run_phantom()
