# 5g-gateway
this project is about using bmv2 as a software switch to be a 5g gateway.


graph TD
    %% 样式定义（区分模块类型）
    classDef initStyle fill:#f0f8fb,stroke:#2d3748,stroke-width:2px
    classDef envStyle fill:#e8f4f8,stroke:#4299e1,stroke-width:2px
    classDef dataStyle fill:#fdf2f8,stroke:#9f7aea,stroke-width:2px
    classDef modelStyle fill:#f5fafe,stroke:#38b2ac,stroke-width:2px
    classDef optimStyle fill:#faf0f5,stroke:#ed8936,stroke-width:2px
    classDef evalStyle fill:#f5f5f5,stroke:#48bb78,stroke-width:2px

    %% 1. 初始化阶段（对应伪代码 Initialize）
    subgraph "初始化模块"
        A["参数初始化"]:::initStyle
        A --> A1["策略网络 π_θ"]:::modelStyle
        A --> A2["扩散模型 D_φ<br/>（Diffusion steps T_d）"]:::modelStyle
        A --> A3["双评论家网络 Q_ψ₁, Q_ψ₂"]:::modelStyle
        A --> A4["目标评论家网络 Q_ψ₁', Q_ψ₂'"]:::modelStyle
        A --> A5["经验回放缓冲区 ℬ<br/>（Batch size B）"]:::dataStyle
        A --> A6["超参数<br/>折扣因子 γ、软更新系数 τ<br/>学习率 α_Q, α_π"]:::initStyle
        %% 目标网络初始同步（伪代码隐含逻辑）
        A3 -->|参数复制| A4
    end

    %% 2. 训练循环（Episode 级）
    B["Episode = 1 到 M"]:::initStyle
    A --> B
    B --> C["初始化 AIGC 环境<br/>观测初始状态 s₀"]:::envStyle
    C --> D["采样初始动作 a₀ ~ π_θ(s₀)"]:::modelStyle
    D --> E["存储 (s₀, a₀) 到轨迹 τ"]:::dataStyle
    E --> F{"是否终端状态？"}:::envStyle

    %% 3. 单步交互循环（Step 级）
    F -->|否| G["生成探索动作 ãₜ ~ D_φ(sₜ)"]:::modelStyle
    G --> H["执行动作 ãₜ 到 AIGC 环境"]:::envStyle
    H --> I["环境返回：奖励 rₜ、下一状态 sₜ₊₁"]:::envStyle
    I --> J["存储转移 (sₜ, ãₜ, rₜ, sₜ₊₁) 到 ℬ"]:::dataStyle
    J --> K{"缓冲区大小 |ℬ| ≥ B？"}:::dataStyle

    %% 4. 网络更新（Batch 级）
    K -->|是| L["从 ℬ 采样批量数据<br/>{(sᵢ, aᵢ, rᵢ, sᵢ')}ᵢ=₁^B"]:::dataStyle
    L --> M["计算目标值 yᵢ<br/>yᵢ = rᵢ + γ·minₖ=1,2 Q_ψₖ'(sᵢ', π_θ(sᵢ'))"]:::modelStyle
    M --> N["更新双评论家网络 Q_ψ₁, Q_ψ₂<br/>ψₖ ← ψₖ - α_Q·∇ψₖ [1/B·Σ(Q_ψₖ(sᵢ,aᵢ)-yᵢ)²]"]:::optimStyle
    N --> O["扩散引导探索的策略梯度更新<br/>更新策略网络 π_θ<br/>θ ← θ + α_π·∇θ J(π_θ)"]:::optimStyle
    O --> P["更新扩散模型 D_φ<br/>最小化扩散损失 ℒ_diff 优化 φ"]:::optimStyle
    P --> Q["软更新目标评论家网络<br/>ψₖ' ← τ·ψₖ + (1-τ)·ψₖ' (k=1,2)"]:::modelStyle
    Q --> R["sₜ ← sₜ₊₁（更新当前状态）"]:::envStyle
    R --> F

    %% 5. 评估与迭代
    K -->|否| R
    F -->|是| S["定期评估策略 π_θ<br/>计算指标：任务成功率/平均延迟/总奖励"]:::evalStyle
    S --> T["保存最优策略 π_θ*"]:::evalStyle
    T --> U["Episode += 1，返回重新初始化环境"]:::initStyle
    U --> C

    %% 6. 训练终止
    B -->|Episode = M| V["返回优化后的最优策略 π_θ*"]:::evalStyle

    %% 关键参数传递标注（增强可读性）
    linkStyle 7 label="ãₜ: 0~23（8网关×3优先级）"
    linkStyle 8 label="rₜ: 基于延迟/优先级计算"
    linkStyle 9 label="转移数据：24维s + 离散a + 浮点r + 24维s'"
    linkStyle 12 label="yᵢ: 目标Q值（稳定监督信号）"
    linkStyle 13 label="∇ψₖ: 评论家梯度，Adam优化"
    linkStyle 14 label="∇θ: 策略梯度，Adam优化"
    linkStyle 15 label="φ: 扩散模型可学习参数"
