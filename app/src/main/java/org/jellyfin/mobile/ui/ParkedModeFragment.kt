package org.jellyfin.mobile.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import org.jellyfin.mobile.databinding.FragmentParkedModeBinding

class ParkedModeFragment : Fragment() {
    private var _binding: FragmentParkedModeBinding? = null
    private val binding: FragmentParkedModeBinding
        get() = _binding!!

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentParkedModeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }
}