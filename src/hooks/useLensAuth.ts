'use client'

import { useState, useCallback } from 'react'
import { useAccount, useSignMessage } from 'wagmi'
import { useToast } from '@/components/shadcn/use-toast'

interface Profile {
  id: string
  handle: string
  picture?: string
  displayName?: string
  stats?: {
    followers: number
    following: number
    posts: number
  }
}

interface ApiError {
  error: string
  status?: number
}

export function useLensAuth() {
  const { address } = useAccount()
  const { signMessageAsync } = useSignMessage()
  const [profile, setProfile] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(false)
  const { toast } = useToast()

  const handleApiResponse = useCallback(async <T,>(response: Response): Promise<T> => {
    const data = await response.json()
    
    if (!response.ok) {
      // Manejar errores específicos
      if (data.error === 'No default profile found') {
        toast({
          title: "No Lens Profile",
          description: "You need to create a Lens profile first",
          variant: "destructive"
        })
        throw new Error('NO_PROFILE')
      }
      
      if (response.status === 401) {
        toast({
          title: "Authentication Error",
          description: "Please reconnect your wallet",
          variant: "destructive"
        })
        throw new Error('UNAUTHORIZED')
      }

      toast({
        title: "Error",
        description: data.error || "Something went wrong",
        variant: "destructive"
      })
      throw new Error(data.error || 'API_ERROR')
    }

    return data as T
  }, [toast])

  const getChallenge = useCallback(async (address: string) => {
    const response = await fetch('/api/lens/challenge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ address })
    })
    
    return handleApiResponse<{
      text: string
      id: string
      profile: Profile
    }>(response)
  }, [handleApiResponse])

  const authenticateWithLens = useCallback(async (params: {
    id: string
    signature: string
    address: string
  }) => {
    const response = await fetch('/api/lens/authenticate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params)
    })

    return handleApiResponse<{
      success: boolean
      needsSignless: boolean
      signlessData?: {
        id: string
        typedData: any
      }
      profile: Profile
    }>(response)
  }, [handleApiResponse])

  const broadcastSignless = useCallback(async (params: {
    id: string
    signature: string
  }) => {
    const response = await fetch('/api/lens/authenticate', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params)
    })

    return handleApiResponse<{
      success: boolean
      txHash?: string
      txId?: string
    }>(response)
  }, [handleApiResponse])

  const authenticate = useCallback(async () => {
    if (!address) {
      toast({
        title: "Error",
        description: "Please connect your wallet first",
        variant: "destructive"
      })
      return
    }

    try {
      setLoading(true)
      
      // 1. Obtener el challenge
      const challengeData = await getChallenge(address)
      
      // 2. Firmar el mensaje
      const signature = await signMessageAsync({ 
        message: challengeData.text 
      })
      
      // 3. Autenticar con Lens
      const authData = await authenticateWithLens({
        id: challengeData.id,
        signature,
        address
      })

      // 4. Manejar signless si es necesario
      if (authData.needsSignless && authData.signlessData) {
        toast({
          title: "Action Required",
          description: "Please sign to enable gasless interactions"
        })

        const signlessSignature = await signMessageAsync({
          message: JSON.stringify(authData.signlessData.typedData)
        })

        await broadcastSignless({
          id: authData.signlessData.id,
          signature: signlessSignature
        })

        toast({
          title: "Success",
          description: "Gasless mode enabled successfully!"
        })
      }

      setProfile(authData.profile)
      toast({
        title: "Connected to Lens",
        description: `Welcome ${authData.profile.handle}!`
      })

      return authData.profile

    } catch (error) {
      if (error instanceof Error) {
        // No mostramos toast para errores ya manejados
        if (!['NO_PROFILE', 'UNAUTHORIZED'].includes(error.message)) {
          toast({
            title: "Error",
            description: "Failed to connect to Lens",
            variant: "destructive"
          })
        }
      }
      return null
    } finally {
      setLoading(false)
    }
  }, [address, signMessageAsync, toast, getChallenge, authenticateWithLens, broadcastSignless])

  return {
    authenticate,
    profile,
    loading,
    isAuthenticated: !!profile
  }
}