# Template Examples - Ready-to-Use Portfolio Components

## 🎨 Complete Portfolio Website Templates & Components

This comprehensive collection provides ready-to-use, production-quality templates and components that you can immediately implement in your portfolio website. All examples include TypeScript, accessibility features, and responsive design.

## 🏠 Complete Page Templates

### **1. Modern Hero Section**

```typescript
// components/sections/HeroSection.tsx
'use client'

import { motion } from 'framer-motion'
import Image from 'next/image'
import Link from 'next/link'
import { ArrowDownIcon, DocumentArrowDownIcon } from '@heroicons/react/24/outline'
import { socialLinks } from '@/data/constants'

const HeroSection = () => {
  const scrollToProjects = () => {
    document.getElementById('projects')?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden bg-gradient-to-br from-slate-50 to-blue-50 dark:from-slate-900 dark:to-slate-800">
      {/* Background Pattern */}
      <div className="absolute inset-0 bg-grid-pattern opacity-5" />
      
      {/* Floating Elements */}
      <div className="absolute top-20 left-10 w-20 h-20 bg-blue-500/10 rounded-full blur-xl animate-pulse" />
      <div className="absolute bottom-20 right-10 w-32 h-32 bg-purple-500/10 rounded-full blur-xl animate-pulse delay-1000" />
      
      <div className="container mx-auto px-6 py-12 relative z-10">
        <div className="max-w-4xl mx-auto text-center">
          {/* Profile Image */}
          <motion.div
            initial={{ opacity: 0, scale: 0.5 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
            className="mb-8 relative inline-block"
          >
            <div className="relative">
              <Image
                src="/images/profile.jpg"
                alt="John Doe - Full Stack Developer"
                width={200}
                height={200}
                className="rounded-full shadow-2xl mx-auto ring-4 ring-white dark:ring-slate-700"
                priority
              />
              <div className="absolute inset-0 rounded-full bg-gradient-to-tr from-blue-500/20 to-purple-500/20" />
            </div>
          </motion.div>

          {/* Main Heading */}
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.2 }}
          >
            <h1 className="text-5xl md:text-7xl font-bold mb-6 bg-gradient-to-r from-slate-900 via-blue-900 to-slate-900 dark:from-white dark:via-blue-200 dark:to-white bg-clip-text text-transparent">
              John Doe
            </h1>
            <div className="text-xl md:text-2xl text-slate-600 dark:text-slate-300 mb-4">
              Senior Full Stack Developer
            </div>
          </motion.div>

          {/* Tagline */}
          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.4 }}
            className="text-lg md:text-xl text-slate-600 dark:text-slate-300 mb-8 max-w-2xl mx-auto leading-relaxed"
          >
            I build{' '}
            <span className="text-blue-600 dark:text-blue-400 font-semibold">scalable web applications</span>
            {' '}that drive business growth. Specializing in React, Node.js, and cloud architecture.
          </motion.p>

          {/* Stats */}
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.6 }}
            className="flex flex-wrap justify-center gap-8 mb-10 text-sm text-slate-600 dark:text-slate-400"
          >
            <div className="text-center">
              <div className="text-2xl font-bold text-slate-900 dark:text-white">6+</div>
              <div>Years Experience</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-slate-900 dark:text-white">50+</div>
              <div>Projects Delivered</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-slate-900 dark:text-white">100K+</div>
              <div>Users Served</div>
            </div>
          </motion.div>

          {/* CTA Buttons */}
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.8 }}
            className="flex flex-col sm:flex-row gap-4 justify-center items-center mb-12"
          >
            <Link
              href="/projects"
              className="inline-flex items-center px-8 py-4 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg shadow-lg hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1"
            >
              View My Work
            </Link>
            <a
              href="/resume.pdf"
              download
              className="inline-flex items-center px-8 py-4 border-2 border-slate-300 dark:border-slate-600 hover:border-blue-600 text-slate-700 dark:text-slate-300 hover:text-blue-600 font-semibold rounded-lg transition-all duration-300"
            >
              <DocumentArrowDownIcon className="w-5 h-5 mr-2" />
              Download Resume
            </a>
          </motion.div>

          {/* Social Links */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.8, delay: 1 }}
            className="flex justify-center space-x-6 mb-12"
          >
            {socialLinks.map((link) => (
              <a
                key={link.name}
                href={link.href}
                className="text-slate-600 dark:text-slate-400 hover:text-blue-600 dark:hover:text-blue-400 transition-colors duration-300"
                aria-label={link.name}
              >
                <link.icon className="w-6 h-6" />
              </a>
            ))}
          </motion.div>

          {/* Scroll Indicator */}
          <motion.button
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.8, delay: 1.2 }}
            onClick={scrollToProjects}
            className="absolute bottom-8 left-1/2 transform -translate-x-1/2 text-slate-400 hover:text-blue-600 transition-colors duration-300"
            aria-label="Scroll to projects"
          >
            <ArrowDownIcon className="w-6 h-6 animate-bounce" />
          </motion.button>
        </div>
      </div>
    </section>
  )
}

export default HeroSection
```

### **2. Interactive Project Card**

```typescript
// components/ui/ProjectCard.tsx
'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import Image from 'next/image'
import Link from 'next/link'
import { 
  EyeIcon, 
  CodeBracketIcon, 
  ArrowTopRightOnSquareIcon,
  CalendarIcon,
  ClockIcon
} from '@heroicons/react/24/outline'
import { Project } from '@/types'

interface ProjectCardProps {
  project: Project
  index: number
}

const ProjectCard = ({ project, index }: ProjectCardProps) => {
  const [isHovered, setIsHovered] = useState(false)

  return (
    <motion.article
      initial={{ opacity: 0, y: 50 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, delay: index * 0.1 }}
      onHoverStart={() => setIsHovered(true)}
      onHoverEnd={() => setIsHovered(false)}
      className="group relative bg-white dark:bg-slate-800 rounded-2xl shadow-lg hover:shadow-2xl transition-all duration-500 overflow-hidden"
    >
      {/* Featured Badge */}
      {project.featured && (
        <div className="absolute top-4 left-4 z-10 bg-gradient-to-r from-yellow-400 to-orange-500 text-white text-xs font-semibold px-3 py-1 rounded-full">
          Featured
        </div>
      )}

      {/* Project Image */}
      <div className="relative h-64 overflow-hidden">
        <Image
          src={project.imageUrl}
          alt={`${project.title} preview`}
          fill
          className={`object-cover transition-transform duration-700 ${
            isHovered ? 'scale-110' : 'scale-100'
          }`}
        />
        <div className={`absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent transition-opacity duration-300 ${
          isHovered ? 'opacity-100' : 'opacity-0'
        }`} />
        
        {/* Overlay Actions */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: isHovered ? 1 : 0, y: isHovered ? 0 : 20 }}
          transition={{ duration: 0.3 }}
          className="absolute bottom-4 left-4 right-4 flex justify-between items-center"
        >
          <div className="flex space-x-2">
            {project.liveUrl && (
              <a
                href={project.liveUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center px-3 py-2 bg-white/90 hover:bg-white text-slate-900 rounded-lg text-sm font-medium transition-colors duration-200"
              >
                <EyeIcon className="w-4 h-4 mr-1" />
                Live Demo
              </a>
            )}
            {project.githubUrl && (
              <a
                href={project.githubUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center px-3 py-2 bg-slate-900/90 hover:bg-slate-900 text-white rounded-lg text-sm font-medium transition-colors duration-200"
              >
                <CodeBracketIcon className="w-4 h-4 mr-1" />
                Code
              </a>
            )}
          </div>
          <div className="text-white/80 text-xs">
            {project.status === 'completed' && '✅ Complete'}
            {project.status === 'in-progress' && '🚧 In Progress'}
            {project.status === 'planned' && '📋 Planned'}
          </div>
        </motion.div>
      </div>

      {/* Content */}
      <div className="p-6">
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <h3 className="text-xl font-bold text-slate-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors duration-300">
            {project.title}
          </h3>
          <Link
            href={`/projects/${project.slug}`}
            className="text-slate-400 hover:text-blue-600 transition-colors duration-200"
            aria-label={`View ${project.title} details`}
          >
            <ArrowTopRightOnSquareIcon className="w-5 h-5" />
          </Link>
        </div>

        {/* Meta Information */}
        <div className="flex items-center space-x-4 text-sm text-slate-500 dark:text-slate-400 mb-3">
          <div className="flex items-center">
            <CalendarIcon className="w-4 h-4 mr-1" />
            {new Date(project.startDate).getFullYear()}
          </div>
          {project.endDate && (
            <div className="flex items-center">
              <ClockIcon className="w-4 h-4 mr-1" />
              {Math.ceil(
                (new Date(project.endDate).getTime() - new Date(project.startDate).getTime()) / 
                (1000 * 60 * 60 * 24 * 30)
              )} months
            </div>
          )}
        </div>

        {/* Description */}
        <p className="text-slate-600 dark:text-slate-300 mb-4 line-clamp-3">
          {project.description}
        </p>

        {/* Technologies */}
        <div className="flex flex-wrap gap-2 mb-4">
          {project.technologies.slice(0, 4).map((tech) => (
            <span
              key={tech}
              className="px-3 py-1 bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300 text-xs font-medium rounded-full"
            >
              {tech}
            </span>
          ))}
          {project.technologies.length > 4 && (
            <span className="px-3 py-1 bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300 text-xs font-medium rounded-full">
              +{project.technologies.length - 4} more
            </span>
          )}
        </div>

        {/* Metrics (if available) */}
        {project.metrics && (
          <div className="grid grid-cols-2 gap-4 pt-4 border-t border-slate-200 dark:border-slate-700">
            {project.metrics.map((metric) => (
              <div key={metric.label} className="text-center">
                <div className="text-lg font-bold text-slate-900 dark:text-white">
                  {metric.value}
                </div>
                <div className="text-xs text-slate-500 dark:text-slate-400">
                  {metric.label}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </motion.article>
  )
}

export default ProjectCard
```

### **3. Contact Form with Validation**

```typescript
// components/forms/ContactForm.tsx
'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { 
  PaperAirplaneIcon, 
  CheckCircleIcon, 
  ExclamationTriangleIcon 
} from '@heroicons/react/24/outline'

const contactSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Please enter a valid email address'),
  company: z.string().optional(),
  subject: z.string().min(5, 'Subject must be at least 5 characters'),
  message: z.string().min(20, 'Message must be at least 20 characters'),
  budget: z.string().optional(),
  timeline: z.string().optional(),
})

type ContactFormData = z.infer<typeof contactSchema>

const ContactForm = () => {
  const [submitStatus, setSubmitStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle')
  const [submitMessage, setSubmitMessage] = useState('')

  const {
    register,
    handleSubmit,
    formState: { errors },
    reset
  } = useForm<ContactFormData>({
    resolver: zodResolver(contactSchema)
  })

  const onSubmit = async (data: ContactFormData) => {
    setSubmitStatus('loading')

    try {
      const response = await fetch('/api/contact', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...data,
          timestamp: new Date().toISOString(),
          source: 'portfolio_contact_form'
        }),
      })

      if (response.ok) {
        setSubmitStatus('success')
        setSubmitMessage('Thank you for your message! I\'ll get back to you within 24 hours.')
        reset()
        
        // Track conversion
        if (typeof window !== 'undefined' && window.gtag) {
          window.gtag('event', 'contact_form_submit', {
            event_category: 'engagement',
            event_label: 'contact_form'
          })
        }
      } else {
        throw new Error('Failed to send message')
      }
    } catch (error) {
      setSubmitStatus('error')
      setSubmitMessage('Sorry, there was an error sending your message. Please try again or email me directly.')
    }
  }

  return (
    <div className="max-w-2xl mx-auto">
      {/* Status Messages */}
      {submitStatus === 'success' && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-6 p-4 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg flex items-center"
        >
          <CheckCircleIcon className="w-5 h-5 text-green-600 dark:text-green-400 mr-3" />
          <p className="text-green-800 dark:text-green-200">{submitMessage}</p>
        </motion.div>
      )}

      {submitStatus === 'error' && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg flex items-center"
        >
          <ExclamationTriangleIcon className="w-5 h-5 text-red-600 dark:text-red-400 mr-3" />
          <p className="text-red-800 dark:text-red-200">{submitMessage}</p>
        </motion.div>
      )}

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        {/* Name and Email Row */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              Name *
            </label>
            <input
              {...register('name')}
              type="text"
              id="name"
              className="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-slate-800 text-slate-900 dark:text-white transition-colors duration-200"
              placeholder="Your full name"
            />
            {errors.name && (
              <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.name.message}</p>
            )}
          </div>

          <div>
            <label htmlFor="email" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              Email *
            </label>
            <input
              {...register('email')}
              type="email"
              id="email"
              className="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-slate-800 text-slate-900 dark:text-white transition-colors duration-200"
              placeholder="your.email@example.com"
            />
            {errors.email && (
              <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.email.message}</p>
            )}
          </div>
        </div>

        {/* Company and Subject Row */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label htmlFor="company" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              Company
            </label>
            <input
              {...register('company')}
              type="text"
              id="company"
              className="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-slate-800 text-slate-900 dark:text-white transition-colors duration-200"
              placeholder="Your company (optional)"
            />
          </div>

          <div>
            <label htmlFor="subject" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              Subject *
            </label>
            <select
              {...register('subject')}
              id="subject"
              className="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-slate-800 text-slate-900 dark:text-white transition-colors duration-200"
            >
              <option value="">Select a subject</option>
              <option value="freelance-project">Freelance Project</option>
              <option value="full-time-opportunity">Full-time Opportunity</option>
              <option value="contract-work">Contract Work</option>
              <option value="collaboration">Collaboration</option>
              <option value="consultation">Consultation</option>
              <option value="other">Other</option>
            </select>
            {errors.subject && (
              <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.subject.message}</p>
            )}
          </div>
        </div>

        {/* Budget and Timeline Row */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label htmlFor="budget" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              Budget Range
            </label>
            <select
              {...register('budget')}
              id="budget"
              className="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-slate-800 text-slate-900 dark:text-white transition-colors duration-200"
            >
              <option value="">Select budget range</option>
              <option value="under-5k">Under $5,000</option>
              <option value="5k-15k">$5,000 - $15,000</option>
              <option value="15k-50k">$15,000 - $50,000</option>
              <option value="50k-plus">$50,000+</option>
              <option value="full-time">Full-time Position</option>
            </select>
          </div>

          <div>
            <label htmlFor="timeline" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              Timeline
            </label>
            <select
              {...register('timeline')}
              id="timeline"
              className="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-slate-800 text-slate-900 dark:text-white transition-colors duration-200"
            >
              <option value="">Select timeline</option>
              <option value="asap">ASAP</option>
              <option value="1-2-weeks">1-2 weeks</option>
              <option value="1-month">Within 1 month</option>
              <option value="2-3-months">2-3 months</option>
              <option value="flexible">Flexible</option>
            </select>
          </div>
        </div>

        {/* Message */}
        <div>
          <label htmlFor="message" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            Message *
          </label>
          <textarea
            {...register('message')}
            id="message"
            rows={6}
            className="w-full px-4 py-3 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white dark:bg-slate-800 text-slate-900 dark:text-white transition-colors duration-200 resize-none"
            placeholder="Tell me about your project, requirements, or opportunity. The more details you provide, the better I can help!"
          />
          {errors.message && (
            <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.message.message}</p>
          )}
        </div>

        {/* Submit Button */}
        <motion.button
          type="submit"
          disabled={submitStatus === 'loading'}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="w-full px-8 py-4 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white font-semibold rounded-lg shadow-lg hover:shadow-xl transition-all duration-300 flex items-center justify-center"
        >
          {submitStatus === 'loading' ? (
            <>
              <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-3"></div>
              Sending...
            </>
          ) : (
            <>
              <PaperAirplaneIcon className="w-5 h-5 mr-2" />
              Send Message
            </>
          )}
        </motion.button>
      </form>

      {/* Alternative Contact Methods */}
      <div className="mt-8 pt-8 border-t border-slate-200 dark:border-slate-700 text-center">
        <p className="text-slate-600 dark:text-slate-400 mb-4">
          Prefer email? Reach me directly at
        </p>
        <a
          href="mailto:john@johndoe.dev"
          className="text-blue-600 dark:text-blue-400 hover:underline font-medium"
        >
          john@johndoe.dev
        </a>
        <p className="text-sm text-slate-500 dark:text-slate-500 mt-4">
          I typically respond within 24 hours
        </p>
      </div>
    </div>
  )
}

export default ContactForm
```

### **4. Skills Visualization Component**

```typescript
// components/sections/SkillsSection.tsx
'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import { skills } from '@/data/skills'
import { Skill } from '@/types'

const SkillsSection = () => {
  const [selectedCategory, setSelectedCategory] = useState<string>('all')
  const [hoveredSkill, setHoveredSkill] = useState<string | null>(null)

  const categories = ['all', 'frontend', 'backend', 'database', 'devops', 'tools']
  
  const filteredSkills = selectedCategory === 'all' 
    ? skills 
    : skills.filter(skill => skill.category === selectedCategory)

  const getProficiencyColor = (proficiency: number) => {
    switch (proficiency) {
      case 5: return 'bg-green-500'
      case 4: return 'bg-blue-500'
      case 3: return 'bg-yellow-500'
      case 2: return 'bg-orange-500'
      case 1: return 'bg-red-500'
      default: return 'bg-gray-500'
    }
  }

  const getProficiencyLabel = (proficiency: number) => {
    switch (proficiency) {
      case 5: return 'Expert'
      case 4: return 'Advanced'
      case 3: return 'Intermediate'
      case 2: return 'Beginner'
      case 1: return 'Learning'
      default: return 'Unknown'
    }
  }

  return (
    <section className="py-20 bg-slate-50 dark:bg-slate-900">
      <div className="container mx-auto px-6">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          viewport={{ once: true }}
          className="text-center mb-12"
        >
          <h2 className="text-4xl font-bold text-slate-900 dark:text-white mb-4">
            Technical Skills
          </h2>
          <p className="text-lg text-slate-600 dark:text-slate-300 max-w-2xl mx-auto">
            Here's my technical expertise across different areas of software development
          </p>
        </motion.div>

        {/* Category Filter */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          viewport={{ once: true }}
          className="flex flex-wrap justify-center gap-4 mb-12"
        >
          {categories.map((category) => (
            <button
              key={category}
              onClick={() => setSelectedCategory(category)}
              className={`px-6 py-3 rounded-full text-sm font-medium transition-all duration-300 ${
                selectedCategory === category
                  ? 'bg-blue-600 text-white shadow-lg'
                  : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-blue-50 dark:hover:bg-slate-700'
              }`}
            >
              {category.charAt(0).toUpperCase() + category.slice(1)}
            </button>
          ))}
        </motion.div>

        {/* Skills Grid */}
        <motion.div
          layout
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"
        >
          {filteredSkills.map((skill, index) => (
            <motion.div
              key={skill.name}
              layout
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.5, delay: index * 0.05 }}
              onHoverStart={() => setHoveredSkill(skill.name)}
              onHoverEnd={() => setHoveredSkill(null)}
              className="bg-white dark:bg-slate-800 rounded-xl p-6 shadow-lg hover:shadow-xl transition-all duration-300 transform hover:-translate-y-2"
            >
              {/* Skill Icon */}
              <div className="flex items-center mb-4">
                {skill.icon && (
                  <div className="w-8 h-8 mr-3 flex items-center justify-center">
                    <img
                      src={`/icons/${skill.icon}.svg`}
                      alt={`${skill.name} icon`}
                      className="w-full h-full"
                    />
                  </div>
                )}
                <h3 className="text-lg font-semibold text-slate-900 dark:text-white">
                  {skill.name}
                </h3>
              </div>

              {/* Proficiency Bar */}
              <div className="mb-3">
                <div className="flex justify-between items-center mb-2">
                  <span className="text-sm text-slate-600 dark:text-slate-400">
                    {getProficiencyLabel(skill.proficiency)}
                  </span>
                  <span className="text-sm text-slate-600 dark:text-slate-400">
                    {skill.yearsOfExperience}y
                  </span>
                </div>
                <div className="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-2">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${(skill.proficiency / 5) * 100}%` }}
                    transition={{ duration: 1, delay: index * 0.1 }}
                    className={`h-2 rounded-full ${getProficiencyColor(skill.proficiency)}`}
                  />
                </div>
              </div>

              {/* Experience Details */}
              {hoveredSkill === skill.name && skill.context && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  className="text-sm text-slate-600 dark:text-slate-400 border-t border-slate-200 dark:border-slate-700 pt-3 mt-3"
                >
                  {skill.context}
                </motion.div>
              )}

              {/* Projects Using This Skill */}
              {skill.projects && skill.projects.length > 0 && (
                <div className="mt-3 pt-3 border-t border-slate-200 dark:border-slate-700">
                  <div className="text-xs text-slate-500 dark:text-slate-500 mb-2">
                    Used in:
                  </div>
                  <div className="flex flex-wrap gap-1">
                    {skill.projects.slice(0, 2).map((project) => (
                      <span
                        key={project}
                        className="text-xs bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 px-2 py-1 rounded"
                      >
                        {project}
                      </span>
                    ))}
                    {skill.projects.length > 2 && (
                      <span className="text-xs text-slate-500 dark:text-slate-500">
                        +{skill.projects.length - 2} more
                      </span>
                    )}
                  </div>
                </div>
              )}
            </motion.div>
          ))}
        </motion.div>

        {/* Skills Summary */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.4 }}
          viewport={{ once: true }}
          className="mt-16 bg-gradient-to-r from-blue-600 to-purple-600 rounded-2xl p-8 text-white text-center"
        >
          <h3 className="text-2xl font-bold mb-4">
            Full Stack Expertise
          </h3>
          <p className="text-blue-100 mb-6 max-w-2xl mx-auto">
            With {skills.reduce((total, skill) => Math.max(total, skill.yearsOfExperience), 0)}+ years of experience, 
            I bring expertise across the entire development stack, from user interfaces to cloud infrastructure.
          </p>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            <div>
              <div className="text-2xl font-bold">{skills.filter(s => s.category === 'frontend').length}</div>
              <div className="text-blue-200">Frontend Technologies</div>
            </div>
            <div>
              <div className="text-2xl font-bold">{skills.filter(s => s.category === 'backend').length}</div>
              <div className="text-blue-200">Backend Technologies</div>
            </div>
            <div>
              <div className="text-2xl font-bold">{skills.filter(s => s.category === 'database').length}</div>
              <div className="text-blue-200">Database Systems</div>
            </div>
            <div>
              <div className="text-2xl font-bold">{skills.filter(s => s.category === 'devops').length}</div>
              <div className="text-blue-200">DevOps Tools</div>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  )
}

export default SkillsSection
```

## 📱 Mobile-First Components

### **5. Responsive Navigation**

```typescript
// components/layout/Navigation.tsx
'use client'

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { 
  Bars3Icon, 
  XMarkIcon, 
  SunIcon, 
  MoonIcon 
} from '@heroicons/react/24/outline'
import { useTheme } from 'next-themes'

const navigation = [
  { name: 'Home', href: '/' },
  { name: 'About', href: '/about' },
  { name: 'Projects', href: '/projects' },
  { name: 'Blog', href: '/blog' },
  { name: 'Contact', href: '/contact' },
]

const Navigation = () => {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [scrolled, setScrolled] = useState(false)
  const pathname = usePathname()
  const { theme, setTheme } = useTheme()

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 50)
    }
    window.addEventListener('scroll', handleScroll)
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  return (
    <header className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
      scrolled 
        ? 'bg-white/90 dark:bg-slate-900/90 backdrop-blur-md shadow-lg' 
        : 'bg-transparent'
    }`}>
      <nav className="container mx-auto px-6 py-4">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <Link 
            href="/" 
            className="text-xl font-bold text-slate-900 dark:text-white hover:text-blue-600 dark:hover:text-blue-400 transition-colors duration-300"
          >
            John Doe
          </Link>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center space-x-8">
            {navigation.map((item) => (
              <Link
                key={item.name}
                href={item.href}
                className={`text-sm font-medium transition-colors duration-300 ${
                  pathname === item.href
                    ? 'text-blue-600 dark:text-blue-400'
                    : 'text-slate-600 dark:text-slate-300 hover:text-blue-600 dark:hover:text-blue-400'
                }`}
              >
                {item.name}
              </Link>
            ))}
            
            {/* Theme Toggle */}
            <button
              onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
              className="p-2 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors duration-300"
              aria-label="Toggle theme"
            >
              {theme === 'dark' ? (
                <SunIcon className="w-5 h-5" />
              ) : (
                <MoonIcon className="w-5 h-5" />
              )}
            </button>
          </div>

          {/* Mobile Menu Button */}
          <div className="md:hidden flex items-center space-x-4">
            <button
              onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
              className="p-2 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300"
              aria-label="Toggle theme"
            >
              {theme === 'dark' ? (
                <SunIcon className="w-5 h-5" />
              ) : (
                <MoonIcon className="w-5 h-5" />
              )}
            </button>
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="p-2 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300"
              aria-label="Toggle menu"
            >
              {mobileMenuOpen ? (
                <XMarkIcon className="w-6 h-6" />
              ) : (
                <Bars3Icon className="w-6 h-6" />
              )}
            </button>
          </div>
        </div>

        {/* Mobile Menu */}
        <AnimatePresence>
          {mobileMenuOpen && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.3 }}
              className="md:hidden mt-4 bg-white dark:bg-slate-800 rounded-lg shadow-lg overflow-hidden"
            >
              <div className="py-4 space-y-1">
                {navigation.map((item) => (
                  <Link
                    key={item.name}
                    href={item.href}
                    onClick={() => setMobileMenuOpen(false)}
                    className={`block px-6 py-3 text-base font-medium transition-colors duration-300 ${
                      pathname === item.href
                        ? 'text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/20'
                        : 'text-slate-600 dark:text-slate-300 hover:text-blue-600 dark:hover:text-blue-400 hover:bg-slate-50 dark:hover:bg-slate-700'
                    }`}
                  >
                    {item.name}
                  </Link>
                ))}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </nav>
    </header>
  )
}

export default Navigation
```

## 🎭 Animation Templates

### **6. Page Transition Wrapper**

```typescript
// components/layout/PageTransition.tsx
'use client'

import { motion } from 'framer-motion'
import { ReactNode } from 'react'

interface PageTransitionProps {
  children: ReactNode
}

const pageVariants = {
  initial: {
    opacity: 0,
    y: 20,
    scale: 0.98
  },
  in: {
    opacity: 1,
    y: 0,
    scale: 1
  },
  out: {
    opacity: 0,
    y: -20,
    scale: 1.02
  }
}

const pageTransition = {
  type: 'tween',
  ease: 'anticipate',
  duration: 0.5
}

const PageTransition = ({ children }: PageTransitionProps) => {
  return (
    <motion.div
      initial="initial"
      animate="in"
      exit="out"
      variants={pageVariants}
      transition={pageTransition}
      className="w-full"
    >
      {children}
    </motion.div>
  )
}

export default PageTransition
```

### **7. Scroll-Triggered Animations**

```typescript
// components/animations/ScrollReveal.tsx
'use client'

import { motion } from 'framer-motion'
import { ReactNode } from 'react'

interface ScrollRevealProps {
  children: ReactNode
  direction?: 'up' | 'down' | 'left' | 'right'
  delay?: number
  duration?: number
  className?: string
}

const ScrollReveal = ({ 
  children, 
  direction = 'up', 
  delay = 0, 
  duration = 0.6, 
  className = '' 
}: ScrollRevealProps) => {
  const directions = {
    up: { y: 50, x: 0 },
    down: { y: -50, x: 0 },
    left: { y: 0, x: 50 },
    right: { y: 0, x: -50 }
  }

  return (
    <motion.div
      initial={{
        opacity: 0,
        ...directions[direction]
      }}
      whileInView={{
        opacity: 1,
        y: 0,
        x: 0
      }}
      transition={{
        duration,
        delay,
        ease: [0.25, 0.25, 0.25, 0.75]
      }}
      viewport={{ once: true, amount: 0.1 }}
      className={className}
    >
      {children}
    </motion.div>
  )
}

export default ScrollReveal
```

## 📊 Data Configuration Templates

### **8. Project Data Structure**

```typescript
// data/projects.ts
import { Project } from '@/types'

export const projects: Project[] = [
  {
    id: 'smartexpense-pro',
    slug: 'smartexpense-pro',
    title: 'SmartExpense Pro',
    description: 'Full-stack expense management platform with OCR receipt scanning and real-time approval workflows.',
    longDescription: `SmartExpense Pro is a comprehensive expense management solution designed for modern distributed teams. 
    
Built with performance and user experience in mind, it handles expense reporting, approval workflows, and financial analytics for companies of all sizes.

The platform features AI-powered receipt scanning with 95% accuracy, real-time approval notifications, and advanced analytics dashboards that provide spending insights and forecasting capabilities.`,
    imageUrl: '/projects/smartexpense-pro.jpg',
    technologies: [
      'React',
      'Next.js',
      'TypeScript',
      'Node.js',
      'PostgreSQL',
      'AWS',
      'Docker',
      'Tailwind CSS'
    ],
    githubUrl: 'https://github.com/johndoe/smartexpense-pro',
    liveUrl: 'https://smartexpense-demo.vercel.app',
    featured: true,
    status: 'completed',
    startDate: '2023-01-15',
    endDate: '2023-05-20',
    metrics: [
      {
        value: '99.9%',
        label: 'Uptime',
        icon: 'uptime'
      },
      {
        value: '$2M+',
        label: 'Monthly Volume',
        icon: 'dollar'
      },
      {
        value: '150+',
        label: 'Companies',
        icon: 'building'
      },
      {
        value: '4.8/5',
        label: 'User Rating',
        icon: 'star'
      }
    ],
    features: [
      {
        title: 'OCR Receipt Scanning',
        description: 'AI-powered text extraction from receipt photos with 95% accuracy',
        impact: 'Reduced manual entry by 90%'
      },
      {
        title: 'Real-time Approvals',
        description: 'Instant notifications and mobile-first approval workflows',
        impact: 'Cut approval time from 5 days to 2 hours'
      },
      {
        title: 'Advanced Analytics',
        description: 'Interactive dashboards with spending insights and forecasting',
        impact: 'Improved budget planning accuracy by 40%'
      }
    ],
    challenges: [
      'Handling high-volume image processing efficiently',
      'Implementing real-time notifications across platforms',
      'Ensuring GDPR compliance for financial data'
    ],
    solutions: [
      'Implemented AWS Lambda for scalable image processing',
      'Used WebSocket connections for real-time updates',
      'Built comprehensive audit trails and data encryption'
    ],
    lessonsLearned: [
      'Proper caching strategies can reduce API response times by 60%',
      'User feedback loops are crucial for feature prioritization',
      'Building for accessibility from day one prevents expensive retrofitting'
    ]
  },
  
  {
    id: 'portfolio-website',
    slug: 'portfolio-website',
    title: 'Developer Portfolio Website',
    description: 'Modern, high-performance portfolio website built with Next.js, featuring 95+ Lighthouse scores and comprehensive SEO optimization.',
    longDescription: `This portfolio website showcases modern web development best practices with a focus on performance, accessibility, and user experience.

Built with Next.js 14 and the App Router, the site achieves 95+ Lighthouse scores across all categories while maintaining excellent developer experience through TypeScript integration and component-based architecture.

The site features dynamic content management, responsive design, and comprehensive SEO optimization to ensure maximum visibility and professional presentation.`,
    imageUrl: '/projects/portfolio-website.jpg',
    technologies: [
      'Next.js',
      'React',
      'TypeScript',
      'Tailwind CSS',
      'Framer Motion',
      'MDX',
      'Vercel'
    ],
    githubUrl: 'https://github.com/johndoe/portfolio-website',
    liveUrl: 'https://johndoe.dev',
    featured: true,
    status: 'completed',
    startDate: '2024-01-01',
    endDate: '2024-02-15',
    metrics: [
      {
        value: '95+',
        label: 'Lighthouse Score',
        icon: 'performance'
      },
      {
        value: '<2s',
        label: 'Load Time',
        icon: 'clock'
      },
      {
        value: '100%',
        label: 'Accessibility',
        icon: 'accessibility'
      },
      {
        value: 'AAA',
        label: 'WCAG Rating',
        icon: 'award'
      }
    ]
  }
]
```

### **9. Configuration Files**

```typescript
// lib/constants.ts
export const siteConfig = {
  name: 'John Doe',
  title: 'John Doe - Senior Full Stack Developer',
  description: 'Senior Full Stack Developer specializing in React, Node.js, and cloud architecture. Building scalable web applications that drive business growth.',
  url: 'https://johndoe.dev',
  author: {
    name: 'John Doe',
    email: 'john@johndoe.dev',
    twitter: '@johndoe',
    linkedin: 'https://linkedin.com/in/johndoe',
    github: 'https://github.com/johndoe'
  },
  keywords: [
    'Full Stack Developer',
    'React Developer', 
    'Node.js Developer',
    'TypeScript',
    'Next.js',
    'Web Development',
    'Software Engineer',
    'JavaScript'
  ],
  socialLinks: [
    {
      name: 'GitHub',
      href: 'https://github.com/johndoe',
      icon: GitHubIcon
    },
    {
      name: 'LinkedIn',
      href: 'https://linkedin.com/in/johndoe',
      icon: LinkedInIcon
    },
    {
      name: 'Twitter',
      href: 'https://twitter.com/johndoe',
      icon: TwitterIcon
    },
    {
      name: 'Email',
      href: 'mailto:john@johndoe.dev',
      icon: EnvelopeIcon
    }
  ]
}

export const resumeConfig = {
  filename: 'john-doe-resume.pdf',
  downloadUrl: '/documents/john-doe-resume.pdf',
  lastUpdated: '2024-01-15',
  formats: ['pdf', 'doc', 'txt']
}

export const analyticsConfig = {
  googleAnalytics: process.env.NEXT_PUBLIC_GA_ID,
  vercelAnalytics: true,
  hotjar: process.env.NEXT_PUBLIC_HOTJAR_ID,
  plausible: process.env.NEXT_PUBLIC_PLAUSIBLE_DOMAIN
}
```

## ✅ Implementation Checklist

### **Quick Start Checklist**

#### **Setup & Configuration** 
- [ ] Clone/create Next.js project with TypeScript
- [ ] Install required dependencies (Framer Motion, Tailwind CSS, etc.)
- [ ] Configure Tailwind CSS with custom design system
- [ ] Set up environment variables
- [ ] Configure next.config.js for optimization

#### **Core Components**
- [ ] Implement HeroSection component
- [ ] Create ProjectCard components
- [ ] Build ContactForm with validation
- [ ] Set up Navigation with mobile menu
- [ ] Add SkillsSection with filtering

#### **Content & Data**
- [ ] Populate projects data structure
- [ ] Add skills and experience data
- [ ] Create blog posts (if applicable)
- [ ] Optimize images and add to public folder
- [ ] Write compelling copy for all sections

#### **Performance & SEO**
- [ ] Configure meta tags and Open Graph
- [ ] Add structured data (JSON-LD)
- [ ] Implement sitemap generation
- [ ] Set up analytics tracking
- [ ] Optimize images and fonts

#### **Deployment & Testing**
- [ ] Deploy to Vercel/Netlify
- [ ] Configure custom domain
- [ ] Run Lighthouse audits
- [ ] Test mobile responsiveness
- [ ] Verify all forms and links work

#### **Professional Integration**
- [ ] Update LinkedIn profile with portfolio link
- [ ] Optimize GitHub profile README
- [ ] Update email signature
- [ ] Cross-post content to relevant platforms
- [ ] Set up attribution tracking

---

## 🔗 Navigation

**⬅️ Previous:** [Professional Integration](./professional-integration.md)  
**➡️ Next:** Back to [README](./README.md)

---

*Template Examples completed: January 2025*