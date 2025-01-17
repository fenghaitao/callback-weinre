
#---------------------------------------------------------------------------------
# weinre is available under *either* the terms of the modified BSD license *or* the
# MIT License (2008). See http:#opensource.org/licenses/alphabetical for full text.
#
# Copyright (c) 2010, 2011 IBM Corporation
#---------------------------------------------------------------------------------

Weinre      = require('../common/Weinre')
IDGenerator = require('../common/IDGenerator')

#-------------------------------------------------------------------------------
module.exports = class NodeStore

    constructor: ->
        @__nodeMap      = {}
        @__nodeDataMap  = {}
        @inspectedNodes = []

        document.addEventListener "DOMSubtreeModified",       handleDOMSubtreeModified, false
        document.addEventListener "DOMNodeInserted",          handleDOMNodeInserted, false
        document.addEventListener "DOMNodeRemoved",           handleDOMNodeRemoved, false
        document.addEventListener "DOMAttrModified",          handleDOMAttrModified, false
        document.addEventListener "DOMCharacterDataModified", handleDOMCharacterDataModified, false

    #---------------------------------------------------------------------------
    addInspectedNode: (nodeId) ->
        @inspectedNodes.unshift nodeId
        @inspectedNodes = @inspectedNodes.slice(0, 5) if @inspectedNodes.length > 5

    #---------------------------------------------------------------------------
    getInspectedNode: (index) ->
        @inspectedNodes[index]

    #---------------------------------------------------------------------------
    getNode: (nodeId) ->
        @__nodeMap[nodeId]

    #---------------------------------------------------------------------------
    checkNodeId: (node) ->
        IDGenerator.checkId node

    #---------------------------------------------------------------------------
    getNodeId: (node) ->
        id = @checkNodeId(node)
        return id if id
        IDGenerator.getId node, @__nodeMap

    #---------------------------------------------------------------------------
    getNodeData: (nodeId, depth) ->
        @serializeNode @getNode(nodeId), depth

    #---------------------------------------------------------------------------
    getPreviousSiblingId: (node) ->
        while true
            sib = node.previousSibling
            return 0 unless sib

            id = @checkNodeId(sib)
            return id if id

            node = sib

    #---------------------------------------------------------------------------
    nextNodeId: () ->
        "" + IDGenerator.next()

    #---------------------------------------------------------------------------
    serializeNode: (node, depth) ->
        nodeName = ""
        nodeValue = null
        localName = null
        id = @getNodeId(node)

        switch node.nodeType

            when Node.TEXT_NODE, Node.COMMENT_NODE, Node.CDATA_SECTION_NODE
                nodeValue = node.nodeValue

            when Node.ATTRIBUTE_NODE
                localName = node.localName

            when Node.DOCUMENT_FRAGMENT_NODE
                break

            else
                nodeName  = node.nodeName
                localName = node.localName

        nodeData =
          id:        id
          nodeType:  node.nodeType
          nodeName:  nodeName
          localName: localName
          nodeValue: nodeValue

        if node.nodeType == Node.ELEMENT_NODE or node.nodeType == Node.DOCUMENT_NODE or node.nodeType == Node.DOCUMENT_FRAGMENT_NODE
          nodeData.childNodeCount = @childNodeCount(node)
          children = @serializeNodeChildren(node, depth)
          nodeData.children = children if children.length

          if node.nodeType == Node.ELEMENT_NODE
            nodeData.attributes = []
            i = 0

            while i < node.attributes.length
              nodeData.attributes.push node.attributes[i].nodeName
              nodeData.attributes.push node.attributes[i].nodeValue
              i++

          else
            if node.nodeType == Node.DOCUMENT_NODE
              nodeData.documentURL = window.location.href

        else if node.nodeType == Node.DOCUMENT_TYPE_NODE
          nodeData.publicId       = node.publicId
          nodeData.systemId       = node.systemId
          nodeData.internalSubset = node.internalSubset

        else if node.nodeType == Node.ATTRIBUTE_NODE
          nodeData.name  = node.nodeName
          nodeData.value = node.nodeValue

        nodeData

    #---------------------------------------------------------------------------
    serializeNodeChildren: (node, depth) ->
        result   = []
        childIds = @childNodeIds(node)

        if depth == 0
            if childIds.length == 1
                childNode = @getNode(childIds[0])
                if childNode.nodeType == Node.TEXT_NODE
                    result.push @serializeNode(childNode)
            return result

        depth--
        i = 0

        while i < childIds.length
            result.push @serializeNode(@getNode(childIds[i]), depth)
            i++

        result

    #---------------------------------------------------------------------------
    childNodeCount: (node) ->
        @childNodeIds(node).length

    #---------------------------------------------------------------------------
    childNodeIds: (node) ->
        ids = []
        i = 0

        for childNode in node.childNodes
            continue if @isToBeSkipped(childNode)
            ids.push @getNodeId(childNode)

        ids

    #---------------------------------------------------------------------------
    isToBeSkipped: (node) ->
        return true unless node
        return true if node.__weinreHighlighter
        return false unless node.nodeType == Node.TEXT_NODE

        not not node.nodeValue.match(/^\s*$/)

#-------------------------------------------------------------------------------
handleDOMSubtreeModified = (event) ->
      return unless event.attrChange
      NodeStore.handleDOMAttrModified event

#-------------------------------------------------------------------------------
handleDOMNodeInserted = (event) ->
      targetId = Weinre.nodeStore.checkNodeId(event.target)
      parentId = Weinre.nodeStore.checkNodeId(event.relatedNode)

      return unless parentId

      child    = Weinre.nodeStore.serializeNode(event.target, 0)
      previous = Weinre.nodeStore.getPreviousSiblingId(event.target)
      Weinre.wi.DOMNotify.childNodeInserted parentId, previous, child

#-------------------------------------------------------------------------------
handleDOMNodeRemoved = (event) ->
      targetId = Weinre.nodeStore.checkNodeId(event.target)
      parentId = Weinre.nodeStore.checkNodeId(event.relatedNode)
      return unless parentId

      if targetId
          Weinre.wi.DOMNotify.childNodeRemoved parentId, targetId
      else
          childCount = Weinre.nodeStore.childNodeCount(event.relatedNode)
          Weinre.wi.DOMNotify.childNodeCountUpdated parentId, childCount

#-------------------------------------------------------------------------------
handleDOMAttrModified = (event) ->
      targetId = Weinre.nodeStore.checkNodeId(event.target)
      return unless targetId
      attrs = []
      i = 0

      while i < event.target.attributes.length
          attrs.push event.target.attributes[i].name
          attrs.push event.target.attributes[i].value
          i++

      Weinre.wi.DOMNotify.attributesUpdated targetId, attrs

#-------------------------------------------------------------------------------
handleDOMCharacterDataModified = (event) ->
      targetId = Weinre.nodeStore.checkNodeId(event.target)
      return unless targetId
      Weinre.wi.DOMNotify.characterDataModified targetId, event.newValue

#-------------------------------------------------------------------------------
require("../common/MethodNamer").setNamesForClass(module.exports)
