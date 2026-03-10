# Unity Sentis / Inference Engine Reference

> Source: Unity Sentis 2.1 Documentation
> https://docs.unity3d.com/Packages/com.unity.sentis@2.1/manual/index.html
> Note: Sentis has been renamed to "Inference Engine" (`com.unity.ai.inference`)

## Overview

Sentis is a neural network inference library for Unity that enables importing and executing trained ML models in real-time across all Unity runtime platforms using end-user device compute (GPU/CPU).

## Core Workflow

```
ONNX Model File --> ModelAsset --> ModelLoader.Load() --> Model
                                                          |
                                                    new Worker(model, backend)
                                                          |
                                              worker.Schedule(inputTensor)
                                                          |
                                              worker.PeekOutput() --> Tensor<T>
```

### Step-by-Step

1. **Import** -- Drag ONNX file into Unity Assets (becomes ModelAsset)
2. **Load** -- `ModelLoader.Load(modelAsset)` creates runtime Model
3. **Create Worker** -- `new Worker(model, BackendType.GPUCompute)`
4. **Prepare Input** -- Create `Tensor<T>` from textures or arrays
5. **Execute** -- `worker.Schedule(inputTensor)`
6. **Read Output** -- `worker.PeekOutput() as Tensor<float>`
7. **Dispose** -- Clean up Worker and Tensors in `OnDestroy()`

## Supported Model Format

- **ONNX** (Open Neural Network Exchange)
- Opset versions 7 through 15
- Models from: Hugging Face, PyTorch Hub, ONNX Model Zoo, Kaggle, Meta Research
- Most ONNX operators supported; unsupported operators cause Worker assertion failures

## Backend Types

| Backend | Execution | Performance | Requirements |
|---------|-----------|-------------|--------------|
| `BackendType.GPUCompute` | GPU compute shaders | Fastest on GPU | `SystemInfo.supportsComputeShaders` must be true |
| `BackendType.CPU` | CPU with Burst | Fastest on CPU | Burst package; slow on WebGL (compiles to WASM) |
| `BackendType.GPUPixel` | GPU pixel shaders | Slower than GPUCompute | Fallback when compute shaders unavailable |

**DirectML acceleration** is available when using GPUCompute with DirectX12 on supported Windows platforms.

### Choosing a Backend

```csharp
BackendType backend;
if (SystemInfo.supportsComputeShaders)
{
    backend = BackendType.GPUCompute;
}
else
{
    backend = BackendType.CPU;
}

var worker = new Worker(runtimeModel, backend);
```

## Complete API Reference

### ModelAsset and ModelLoader

```csharp
using Unity.Sentis;

// Load from Inspector reference
public ModelAsset modelAsset;
Model runtimeModel = ModelLoader.Load(modelAsset);

// Load from Resources folder
ModelAsset asset = Resources.Load("model-file") as ModelAsset;
Model model = ModelLoader.Load(asset);
```

### Worker (Inference Engine)

```csharp
// Create worker
Worker worker = new Worker(runtimeModel, BackendType.GPUCompute);

// Run inference
worker.Schedule(inputTensor);

// Get output (does not take ownership of tensor)
Tensor<float> output = worker.PeekOutput() as Tensor<float>;

// Get named output
Tensor<float> namedOutput = worker.PeekOutput("output_name") as Tensor<float>;

// Dispose when done
worker.Dispose();
```

### Tensor Creation

```csharp
using Unity.Sentis;

// From texture (image input)
Texture2D texture = Resources.Load("image") as Texture2D;
Tensor<float> imageTensor = TextureConverter.ToTensor(texture);

// From float array
float[] data = new float[] { 1.0f, 2.0f, 3.0f, 4.0f };
Tensor<float> floatTensor = new Tensor<float>(new TensorShape(1, 4), data);

// From int array
int[] intData = new int[] { 1, 2, 3, 4 };
Tensor<int> intTensor = new Tensor<int>(new TensorShape(4), intData);

// TensorShape defines dimensions
var shape = new TensorShape(1, 3, 224, 224); // batch, channels, height, width
```

### TextureConverter

```csharp
// Texture to Tensor
Tensor<float> tensor = TextureConverter.ToTensor(texture2D);

// Tensor to Texture (for output visualization)
// Process output tensor back to texture for display
```

### TensorShape

```csharp
// Define tensor dimensions
var shape1D = new TensorShape(10);           // 1D: 10 elements
var shape2D = new TensorShape(3, 4);         // 2D: 3x4
var shape4D = new TensorShape(1, 3, 224, 224); // Batch, Channels, H, W
```

## Complete Inference Examples

### Image Classification

```csharp
using UnityEngine;
using Unity.Sentis;

public class ImageClassifier : MonoBehaviour
{
    public ModelAsset modelAsset;
    public Texture2D inputImage;

    Model runtimeModel;
    Worker worker;

    void Start()
    {
        runtimeModel = ModelLoader.Load(modelAsset);
        worker = new Worker(runtimeModel, BackendType.GPUCompute);
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Space))
        {
            Classify();
        }
    }

    void Classify()
    {
        // Convert image to tensor
        Tensor<float> inputTensor = TextureConverter.ToTensor(inputImage);

        // Run inference
        worker.Schedule(inputTensor);

        // Get output probabilities
        Tensor<float> outputTensor = worker.PeekOutput() as Tensor<float>;

        // Find highest probability class
        // Process outputTensor values...

        // Clean up input
        inputTensor.Dispose();
    }

    void OnDestroy()
    {
        worker?.Dispose();
    }
}
```

### Simple Data Inference

```csharp
using UnityEngine;
using Unity.Sentis;

public class DataPredictor : MonoBehaviour
{
    public ModelAsset modelAsset;

    Model runtimeModel;
    Worker worker;

    void Start()
    {
        runtimeModel = ModelLoader.Load(modelAsset);

        // Choose backend based on platform
        BackendType backend = SystemInfo.supportsComputeShaders
            ? BackendType.GPUCompute
            : BackendType.CPU;

        worker = new Worker(runtimeModel, backend);
    }

    public float[] Predict(float[] inputData)
    {
        // Create input tensor
        var inputTensor = new Tensor<float>(
            new TensorShape(1, inputData.Length), inputData);

        // Execute
        worker.Schedule(inputTensor);

        // Read output
        Tensor<float> outputTensor = worker.PeekOutput() as Tensor<float>;

        // Copy results to array
        // Note: Access tensor data for processing
        float[] results = new float[outputTensor.shape[1]];
        // Process output tensor...

        inputTensor.Dispose();
        return results;
    }

    void OnDestroy()
    {
        worker?.Dispose();
    }
}
```

## Performance Considerations

- **Model complexity** directly affects inference time
- **Backend selection** has significant impact; GPUCompute is fastest when available
- **Tensor allocation** can cause GC pressure; reuse tensors where possible
- **WebGL + CPU backend** is very slow due to Burst-to-WebAssembly compilation
- **Profile** using Unity Profiler to measure model execution time
- **Unsupported operators** cause runtime assertion failures; check operator compatibility

## Anti-Patterns

- **Not disposing Worker** -- Always call `worker.Dispose()` in `OnDestroy()` to prevent GPU/CPU resource leaks
- **Not disposing Tensors** -- Input tensors should be disposed after scheduling; output tensors from `PeekOutput()` are owned by the Worker
- **Running inference every frame** -- ML inference is expensive; schedule only when needed or use a coroutine with frame budgeting
- **Ignoring platform capabilities** -- Always check `SystemInfo.supportsComputeShaders` before using GPUCompute backend
- **Large models on mobile** -- Mobile GPU memory is limited; consider model quantization or smaller architectures
- **Blocking the main thread** -- For large models, consider splitting inference across frames

## Migration Note

Sentis has been renamed to **Inference Engine** with the package namespace changing to `com.unity.ai.inference`. Existing Sentis code should be migrated to the new package for future updates.

## Additional Resources

- [Sentis Manual](https://docs.unity3d.com/Packages/com.unity.sentis@2.1/manual/index.html)
- [Create a Worker](https://docs.unity3d.com/Packages/com.unity.sentis@2.1/manual/create-an-engine.html)
- [ONNX Model Zoo](https://github.com/onnx/models)
- [Hugging Face Models](https://huggingface.co/models)
