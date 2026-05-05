export enum Curves {
  Linear = 'linear',
  Ease = 'ease',
  EaseIn = 'easeIn',
  EaseOut = 'easeOut',
  EaseInOut = 'easeInOut',
  Decelerate = 'decelerate',
  BounceIn = 'bounceIn',
  BounceOut = 'bounceOut',
  BounceInOut = 'bounceInOut',
  ElasticIn = 'elasticIn',
  ElasticOut = 'elasticOut',
  ElasticInOut = 'elasticInOut',
  FastOutSlowIn = 'fastOutSlowIn',
  
  // Sine
  EaseInSine = 'easeInSine',
  EaseOutSine = 'easeOutSine',
  EaseInOutSine = 'easeInOutSine',
  
  // Quad
  EaseInQuad = 'easeInQuad',
  EaseOutQuad = 'easeOutQuad',
  EaseInOutQuad = 'easeInOutQuad',
  
  // Cubic
  EaseInCubic = 'easeInCubic',
  EaseOutCubic = 'easeOutCubic',
  easeInOutCubic = 'easeInOutCubic',
  
  // Quart
  EaseInQuart = 'easeInQuart',
  EaseOutQuart = 'easeOutQuart',
  EaseInOutQuart = 'easeInOutQuart',
  
  // Quint
  EaseInQuint = 'easeInQuint',
  EaseOutQuint = 'easeOutQuint',
  EaseInOutQuint = 'easeInOutQuint',
  
  // Expo
  EaseInExpo = 'easeInExpo',
  EaseOutExpo = 'easeOutExpo',
  EaseInOutExpo = 'easeInOutExpo',
  
  // Circ
  EaseInCirc = 'easeInCirc',
  EaseOutCirc = 'easeOutCirc',
  EaseInOutCirc = 'easeInOutCirc',
  
  // Back
  EaseInBack = 'easeInBack',
  EaseOutBack = 'easeOutBack',
  EaseInOutBack = 'easeInOutBack',
  
  // Specialized
  FastLinearToSlowEaseIn = 'fastLinearToSlowEaseIn',
  SlowMiddle = 'slowMiddle',
  FastEaseInToSlowEaseOut = 'fastEaseInToSlowEaseOut',
  LinearToEaseOut = 'linearToEaseOut',
  EaseInToLinear = 'easeInToLinear'
}

// Utility type for using the string values directly
export type Curve = `${Curves}`;