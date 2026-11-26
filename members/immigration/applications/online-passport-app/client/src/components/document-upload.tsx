"use client"

import { useState, useCallback } from "react"
import { useDropzone } from "react-dropzone"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"
import { Upload, File, X, Check, AlertCircle, Eye } from "lucide-react"
import { cn } from "@/lib/utils"

interface UploadedFile {
  id: string
  file: File
  preview?: string
  status: "uploading" | "completed" | "error"
  progress: number
  error?: string
}

interface DocumentUploadProps {
  title: string
  description: string
  acceptedTypes: string[]
  maxSize: number // in MB
  required?: boolean
  multiple?: boolean
  onFilesChange: (files: UploadedFile[]) => void
  existingFiles?: UploadedFile[]
}

export function DocumentUpload({
  title,
  description,
  acceptedTypes,
  maxSize,
  required = false,
  multiple = false,
  onFilesChange,
  existingFiles = [],
}: DocumentUploadProps) {
  const [files, setFiles] = useState<UploadedFile[]>(existingFiles)
  const [isDragActive, setIsDragActive] = useState(false)

  const onDrop = useCallback(
    (acceptedFiles: File[], rejectedFiles: any[]) => {
      // Handle rejected files
      if (rejectedFiles.length > 0) {
        console.log("Rejected files:", rejectedFiles)
      }

      // Process accepted files
      const newFiles: UploadedFile[] = acceptedFiles.map((file) => ({
        id: Math.random().toString(36).substr(2, 9),
        file,
        preview: file.type.startsWith("image/") ? URL.createObjectURL(file) : undefined,
        status: "uploading",
        progress: 0,
      }))

      const updatedFiles = multiple ? [...files, ...newFiles] : newFiles
      setFiles(updatedFiles)
      onFilesChange(updatedFiles)

      // Simulate upload progress
      newFiles.forEach((uploadFile) => {
        simulateUpload(uploadFile.id)
      })
    },
    [files, multiple, onFilesChange],
  )

  const {
    getRootProps,
    getInputProps,
    isDragActive: dropzoneActive,
  } = useDropzone({
    onDrop,
    accept: acceptedTypes.reduce((acc, type) => ({ ...acc, [type]: [] }), {}),
    maxSize: maxSize * 1024 * 1024,
    multiple,
    onDragEnter: () => setIsDragActive(true),
    onDragLeave: () => setIsDragActive(false),
  })

  const simulateUpload = (fileId: string) => {
    let progress = 0
    const interval = setInterval(() => {
      progress += Math.random() * 30
      if (progress >= 100) {
        progress = 100
        clearInterval(interval)
        setFiles((prev) => prev.map((f) => (f.id === fileId ? { ...f, status: "completed", progress: 100 } : f)))
      } else {
        setFiles((prev) => prev.map((f) => (f.id === fileId ? { ...f, progress } : f)))
      }
    }, 200)
  }

  const removeFile = (fileId: string) => {
    const updatedFiles = files.filter((f) => f.id !== fileId)
    setFiles(updatedFiles)
    onFilesChange(updatedFiles)
  }

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Number.parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i]
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h4 className="font-medium text-foreground">
            {title}
            {required && <span className="text-destructive ml-1">*</span>}
          </h4>
          <p className="text-sm text-muted-foreground">{description}</p>
        </div>
        <Badge variant="outline" className="text-xs">
          Max {maxSize}MB
        </Badge>
      </div>

      {/* Upload Area */}
      <Card
        className={cn(
          "border-2 border-dashed transition-colors cursor-pointer",
          isDragActive || dropzoneActive
            ? "border-primary bg-primary/5"
            : "border-muted-foreground/25 hover:border-muted-foreground/50",
        )}
      >
        <CardContent className="p-6">
          <div {...getRootProps()} className="text-center">
            <input {...getInputProps()} />
            <Upload className="h-10 w-10 text-muted-foreground mx-auto mb-4" />
            <p className="text-sm text-muted-foreground mb-2">
              {isDragActive || dropzoneActive ? "Drop files here..." : "Drag and drop files here, or click to browse"}
            </p>
            <p className="text-xs text-muted-foreground">
              Accepted formats: {acceptedTypes.join(", ")} • Max size: {maxSize}MB
            </p>
          </div>
        </CardContent>
      </Card>

      {/* Uploaded Files */}
      {files.length > 0 && (
        <div className="space-y-3">
          {files.map((file) => (
            <Card key={file.id} className="p-4">
              <div className="flex items-center space-x-4">
                {/* File Icon/Preview */}
                <div className="flex-shrink-0">
                  {file.preview ? (
                    <img
                      src={file.preview || "/placeholder.svg"}
                      alt="Preview"
                      className="h-12 w-12 object-cover rounded border"
                    />
                  ) : (
                    <div className="h-12 w-12 bg-muted rounded flex items-center justify-center">
                      <File className="h-6 w-6 text-muted-foreground" />
                    </div>
                  )}
                </div>

                {/* File Info */}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-foreground truncate">{file.file.name}</p>
                  <p className="text-xs text-muted-foreground">{formatFileSize(file.file.size)}</p>

                  {/* Progress Bar */}
                  {file.status === "uploading" && <Progress value={file.progress} className="h-1 mt-2" />}
                </div>

                {/* Status */}
                <div className="flex items-center space-x-2">
                  {file.status === "completed" && <Check className="h-5 w-5 text-green-600" />}
                  {file.status === "error" && <AlertCircle className="h-5 w-5 text-destructive" />}
                  {file.preview && (
                    <Button variant="ghost" size="sm">
                      <Eye className="h-4 w-4" />
                    </Button>
                  )}
                  <Button variant="ghost" size="sm" onClick={() => removeFile(file.id)}>
                    <X className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  )
}
