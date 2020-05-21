#!/usr/bin/env python
#coding=utf-8
import os
import re
import sys
import argparse
import subprocess

#project
PROJECT_PATH = os.path.abspath(os.path.dirname(__file__))


def __find_matches(dirpath, name, pattern):
    for i, line in enumerate(open(os.path.join(dirpath, name))):
        for match in re.finditer(pattern, line):
            print 'In %s line %s: %s' % (os.path.join(dirpath, name), i+1, line)

def __empty_search(isPath):
    pm_pattern = re.compile("@param\s\{.*\}\s\w*\s\.")
    exten = '.adoc'
    if not isPath=='':
        if os.path.isdir(isPath):
            dirpath = isPath;
            for file in os.listdir(dirpath):
                if file.lower().endswith(exten):
                    __find_matches(dirpath, file, pm_pattern)
        else:
            bPath = os.path.basename(isPath)
            fPath = isPath.replace(bPath, '')
            if isPath.lower().endswith(exten):
                __find_matches(fPath, bPath, pm_pattern)
    else:
        for dirpath, dirnames, files in os.walk(PROJECT_PATH):
            relativeDir = os.path.relpath(dirpath, PROJECT_PATH)
            for name in files:
                if name.lower().endswith(exten):
                    __find_matches(relativeDir, name, pm_pattern)


def __search_unused_sample(dirpath, sampleName):
    isFounded = 0
    for file in os.listdir(dirpath):
        if file.lower().endswith('.adoc'):
            with open (os.path.join(dirpath,file), "r") as f:
                reslt = re.findall('@example\s'+sampleName[0:-5],f.read(),re.MULTILINE)
                if len(reslt) > 0:
                    isFounded += 1

    if isFounded == 0:
        print 'Not found usage sample: %s (path %s)' % (sampleName, dirpath)


def __unused_samples():
    for dirpath, dirnames, files in os.walk(PROJECT_PATH):
        for name in dirnames:
            if name.lower() == '_samples':
                for file in os.listdir(os.path.join(dirpath, name)):
                    if file.lower().endswith('.html'):
                        __search_unused_sample(os.path.join(dirpath, name, '..'), file)


def __check_sample_exist(dirpath, name, pattern):
    for i, line in enumerate(open(os.path.join(dirpath, name))):
        for match in re.finditer(pattern, line):
            if not (os.path.isfile(os.path.join(dirpath, '_samples' ,match.group(1) + '.html'))):
                print 'Sample not exist. In %s line %s: %s' % (os.path.join(dirpath, name), i+1, line)

def __without_sample(isPath):
    isPath = os.path.join(PROJECT_PATH, isPath)
    for dirpath, dirnames, files in os.walk(isPath):
        relativeDir = os.path.relpath(dirpath, PROJECT_PATH)
        for name in files:
            if name.lower().endswith('.adoc'):
                with open(os.path.join(dirpath,name), 'r') as myfile:
                    for match in re.finditer('\/\*\*((?:[^*]|\*[^\/])*)\*\/\s*\n(\S*)', myfile.read()):
                        if ("@" in match.group(1)) and not ("@example" in match.group(1)) and not ("@namespace" in match.group(1)) and not ("@listing" in match.group(1)):
                            print 'No sample or listing in '+os.path.join(relativeDir,name) + '@ '+match.group(2);
                    myfile.close()

def __unexistable_examples(isPath):
    ex_pattern = re.compile("@example\s*([\w.]*)[\s\n]+")
    exten = '.adoc'
    if not isPath=='':
        if os.path.isdir(isPath):
            dirpath = isPath;
            for file in os.listdir(dirpath):
                if file.lower().endswith(exten):
                    __check_sample_exist(dirpath, file, ex_pattern)
        else:
            if isPath.lower().endswith(exten):
                bPath = os.path.basename(isPath)
                fPath = isPath.replace(bPath, '')
                __check_sample_exist(fPath, bPath, ex_pattern)
    else:
        for dirpath, dirnames, files in os.walk(PROJECT_PATH):
            relativeDir = os.path.relpath(dirpath, PROJECT_PATH)
            for name in files:
                if name.lower().endswith(exten):
                    __check_sample_exist(relativeDir, name, ex_pattern)

#=======================================================================================================================
#           Main
#=======================================================================================================================
def __exec_main_script():
    isPath = ''
    checkSamples = 1
    checkSamplesListings = 0
    checkSamplesOnly = ''
    total = len(sys.argv)
    for i in xrange(total):
        if sys.argv[i]=='-p' and not i==total-1:
          isPath = sys.argv[i+1]
          checkSamples = ''
        if sys.argv[i]=='-so':
            checkSamplesOnly = 1
        if sys.argv[i]=='-sl':
            checkSamplesListings = 1

    if checkSamplesListings == 1:
        __without_sample(isPath)
        checkSamples = 0

    if checkSamplesOnly == '':
        __empty_search(isPath)
        __unexistable_examples(isPath)
    if checkSamples == 1:
        __unused_samples()

if __name__ == '__main__':
    try:
        __exec_main_script()
    except StandardError as e:
        print e
        sys.exit(1)
